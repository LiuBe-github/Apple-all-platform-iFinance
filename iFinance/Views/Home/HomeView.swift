//
//  HomeView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI
import Combine
import UIKit
internal import CoreData

// MARK: - 分享数据载体
private struct SharePayload: Identifiable {
    let id = UUID()
    let imageURL: URL
}

// MARK: - 图片缓存（内存 + 磁盘 双层缓存）
private final class ImageCache {
    static let shared = ImageCache()

    /// 内存缓存（NSCache，系统在内存压力时自动清理）
    private let memoryCache = NSCache<NSString, UIImage>()

    /// 磁盘缓存目录
    private let diskDirectory: URL

    /// 磁盘缓存有效期：7 天
    private let diskExpiry: TimeInterval = 7 * 24 * 60 * 60

    /// 正在进行的请求（防止重复请求同一URL）
    private var inflightTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {
        memoryCache.countLimit = 30
        memoryCache.totalCostLimit = 80 * 1024 * 1024 // 80 MB

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskDirectory = caches.appendingPathComponent("iFinance/ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)

        // 启动时清理过期文件
        cleanupExpiredDiskCache()
    }

    // MARK: - 内存缓存

    func get(_ key: String) -> UIImage? {
        memoryCache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
    }

    // MARK: - 磁盘缓存

    func getFromDisk(_ key: String) -> UIImage? {
        let url = diskURL(for: key)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < diskExpiry,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        // 回填内存缓存
        set(image, for: key)
        return image
    }

    func saveToDisk(_ image: UIImage, for key: String) {
        guard let data = image.jpegData(compressionQuality: 0.72) else { return }
        let url = diskURL(for: key)
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - 请求去重

    func setInflightTask(_ task: Task<UIImage?, Never>, forKey key: String) {
        inflightTasks[key] = task
    }

    func getInflightTask(forKey key: String) -> Task<UIImage?, Never>? {
        inflightTasks[key]
    }

    func removeInflightTask(forKey key: String) {
        inflightTasks.removeValue(forKey: key)
    }

    // MARK: - 辅助

    private func diskURL(for key: String) -> URL {
        let hash = key.utf8.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent("\(hash).jpg")
    }

    private func cleanupExpiredDiskCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: self.diskDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }

            let now = Date()
            for file in files {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let modified = attrs[.modificationDate] as? Date,
                   now.timeIntervalSince(modified) > self.diskExpiry {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
}

// MARK: - 图片降采样工具
private enum ImageDownsampler {
    /// 将图片降采样到目标尺寸（保持宽高比）
    /// 目标尺寸设为屏幕密度的 1x 即可，因为 displayScale 由上层处理
    static func downsample(_ imageData: Data, to maxSize: CGSize) -> UIImage? {
        let imageSourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions as CFDictionary) else { return nil }

        // 解码时直接降采样到目标尺寸
        let maxDimension = max(maxSize.width, maxSize.height)
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - 图片加载器
@MainActor
private final class ImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoaded: Bool = false

    /// 当前加载的URL（用于防竞态）
    private var currentURL: URL?

    /// 目标显示尺寸（用于降采样）
    private var targetSize: CGSize = CGSize(width: 400, height: 560)

    func load(url: URL, targetSize: CGSize = CGSize(width: 400, height: 560)) {
        self.targetSize = targetSize
        let key = url.absoluteString

        // 1️⃣ 内存缓存命中 → 直接返回
        if let cached = ImageCache.shared.get(key) {
            self.image = cached
            self.isLoaded = true
            return
        }

        // 2️⃣ 磁盘缓存命中 → 回填内存并返回
        if let diskCached = ImageCache.shared.getFromDisk(key) {
            self.image = diskCached
            self.isLoaded = true
            return
        }

        // 3️⃣ 检查是否有正在进行的相同请求（请求去重）
        if let existingTask = ImageCache.shared.getInflightTask(forKey: key) {
            currentURL = url
            Task {
                if let result = await existingTask.value {
                    guard url == currentURL else { return }
                    self.image = result
                    self.isLoaded = true
                }
            }
            return
        }

        // 4️⃣ 发起网络请求（带超时 + 降采样）
        currentURL = url
        let task = Task<UIImage?, Never> {
            await performDownload(url: url, key: key)
        }
        ImageCache.shared.setInflightTask(task, forKey: key)

        Task {
            let result = await task.value
            ImageCache.shared.removeInflightTask(forKey: key)
            guard url == currentURL else { return } // 防止旧结果覆盖新请求

            if let img = result {
                self.image = img
            }
            self.isLoaded = true
        }
    }

    // MARK: - 核心下载逻辑

    private func performDownload(url: URL, key: String) async -> UIImage? {
        do {
            // 配置 URLSession：10 秒超时
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForResource = 10
            config.timeoutIntervalForRequest = 8
            config.urlCache = nil // 不使用系统的 URL 缓存，我们自己管理
            let session = URLSession(configuration: config)

            let (data, response) = try await session.data(from: url)

            // 检查 HTTP 状态码
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // 降采样：从大图直接解码为小图（节省 90%+ 内存）
            if let downsampled = ImageDownsampler.downsample(data, to: targetSize) {
                // 写入双层缓存
                ImageCache.shared.set(downsampled, for: key)
                ImageCache.shared.saveToDisk(downsampled, for: key)
                return downsampled
            }
            return nil
        } catch {
            return nil
        }
    }

    /// 预加载（供下一条卡片预加载使用）—— 使用较小的目标尺寸以节省资源
    func preload(url: URL) async {
        let key = url.absoluteString
        guard ImageCache.shared.get(key) == nil,
              ImageCache.shared.getFromDisk(key) == nil else { return }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config)

        guard let (data, _) = try? await session.data(from: url),
              let downsampled = ImageDownsampler.downsample(data, to: CGSize(width: 300, height: 420))
        else { return }

        ImageCache.shared.set(downsampled, for: key)
        ImageCache.shared.saveToDisk(downsampled, for: key)
    }
}

// MARK: - 名言卡片视图（用于首页展示）
struct SentenceCardView: View {
    let sentence: DailySentence

    @StateObject private var loader = ImageLoader()

    /// 卡片的目标显示尺寸（用于图片降采样）
    var displaySize: CGSize = CGSize(width: 375, height: 520)

    /// 图片宽高比（高度 = 宽度 / aspectRatio）
    /// 0.75 → 约 4:3 竖图比例
    private let imageAspectRatio: CGFloat = 0.75

    private var imageURL: URL? {
        let seed = abs(sentence.content.hashValue) % 1000
        return URL(string: "https://picsum.photos/seed/\(seed)/800/1200")
    }

    /// 失败兜底渐变
    private var fallbackGradient: LinearGradient {
        let hue = Double(abs(sentence.content.hashValue) % 360) / 360
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.35, brightness: 0.45),
                Color(hue: (hue + 0.1).truncatingRemainder(dividingBy: 1),
                      saturation: 0.25, brightness: 0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / imageAspectRatio

            ZStack(alignment: .bottomLeading) {

                // ── 背景：缓存图 / 骨架屏 / 兜底渐变 ──
                Group {
                    if let img = loader.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: w, height: h)
                            .clipped()
                            .transition(.opacity.animation(.easeIn(duration: 0.25)))
                    } else if !loader.isLoaded {
                        // 骨架屏
                        ZStack {
                            Color(UIColor.systemGray5)
                            ProgressView().tint(Color(UIColor.systemGray2))
                        }
                        .frame(width: w, height: h)
                    } else {
                        fallbackGradient
                            .frame(width: w, height: h)
                    }
                }

                // ── 底部渐变遮罩 ──
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.12), location: 0.42),
                        .init(color: .black.opacity(0.70), location: 0.76),
                        .init(color: .black.opacity(0.86), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: h)

                // ── 文字 ──
                VStack(alignment: .leading, spacing: 10) {
                    Text("\u{201C}")
                        .font(.system(size: 52, weight: .bold, design: .serif))
                        .foregroundStyle(.white.opacity(0.30))
                        .offset(y: 10)

                    Text(sentence.content)
                        .font(.system(size: 19, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)

                    HStack {
                        Spacer()
                        Text("\(sentence.note)")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(.white.opacity(0.72))
                            .italic()
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 160)
            }
        }
        .aspectRatio(imageAspectRatio, contentMode: .fit)
        .onAppear {
            guard let url = imageURL else { return }
            loader.load(url: url, targetSize: displaySize)
        }
    }
}

// MARK: - 今日结余卡片（首页顶部，紧凑版）
private struct TodayBalanceCard: View {
    let income: Decimal
    let expense: Decimal
    let balance: Decimal
    let billCount: Int

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = .autoupdatingCurrent
        return f
    }()

    private func formatted(_ value: Decimal) -> String {
        Self.currencyFormatter.maximumFractionDigits = value == 0 || abs(value) >= 1000 ? 0 : 2
        Self.currencyFormatter.minimumFractionDigits = 0
        return Self.currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "¥0"
    }

    /// 日期文字
    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            // ── 左侧：金额 ──
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatted(balance))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(balance >= 0 ? Color(red: 0.18, green: 0.78, blue: 0.44) : Color(red: 1.0, green: 0.27, blue: 0.23))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(balance >= 0 ? String(localized: "home.surplus") : String(localized: "home.deficit"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(balance >= 0 ? .green.opacity(0.7) : .red.opacity(0.7))
                }
            }

            Spacer()

            // ── 右侧：三栏统计 ──
            HStack(spacing: 14) {
                miniStat(icon: "arrow.down.circle.fill", color: .green,
                         value: formatted(income), label: String(localized: "home.income_label"))
                miniStat(icon: "arrow.up.circle.fill", color: .red,
                         value: formatted(expense), label: String(localized: "home.expense_label"))
                miniStat(icon: "list.bullet.clipboard.fill", color: .blue,
                         value: "\(billCount)", label: String(localized: "home.count_label"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .appGlassCard(cornerRadius: 20)
    }

    private func miniStat(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
        }
    }
}

// MARK: - 分享专用卡片视图（包含当日记账统计）
private struct ShareCardView: View {
    let sentence: DailySentence
    let backgroundImage: UIImage?
    let dailyBalance: Decimal   // 当日结余
    let incomeTotal: Decimal    // 当日收入
    let expenseTotal: Decimal   // 当日支出
    let billCount: Int          // 当日笔数
    let dateText: String        // 日期文字

    /// 图片区域宽高比（与首页一致）
    private let imageAspectRatio: CGFloat = 0.75

    private var formattedBalance: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 2
        return f.string(from: NSDecimalNumber(decimal: dailyBalance)) ?? "¥0.00"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 上半部分：名言图片（自适应高度） ──
            GeometryReader { geo in
                let w = geo.size.width
                let h = w / imageAspectRatio

                ZStack(alignment: .bottomLeading) {
                    // 背景
                    Group {
                        if let img = backgroundImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: w, height: h)
                                .clipped()
                        } else {
                            placeholderGradient
                                .frame(width: w, height: h)
                        }
                    }

                    // 底部渐变遮罩
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.3),
                            .init(color: .black.opacity(0.85), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: h)

                    // 名言文字
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\u{201C}")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundStyle(.white.opacity(0.25))

                        Text(sentence.content)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)

                        HStack {
                            Spacer()
                            Text("—— \(sentence.note)")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(.white.opacity(0.65))
                                .italic()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
            }
            .aspectRatio(imageAspectRatio, contentMode: .fit)

            // ── 下半部分：当日记账统计 ──
            VStack(spacing: 14) {
                // 日期标题
                Text(dateText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                // 结余金额
                Text(formattedBalance)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(dailyBalance >= 0 ? Color(red: 0.18, green: 0.78, blue: 0.44) : Color(red: 1.0, green: 0.27, blue: 0.23))

                Text(dailyBalance >= 0 ? String(localized: "home.share_surplus") : String(localized: "home.share_deficit"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(dailyBalance >= 0 ? .green : .red)

                // 三栏统计
                HStack(spacing: 20) {
                    statColumn(title: "home.share_income", value: incomeTotal, color: .green)
                    Divider().frame(height: 32)
                    statColumn(title: "home.share_expense", value: expenseTotal, color: .red)
                    Divider().frame(height: 32)
                    statColumn(title: "home.share_count", value: "\(billCount)", color: .blue)
                }
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color(UIColor.secondarySystemBackground))
        }
    }

    private var placeholderGradient: some View {
        let hue = Double(abs(sentence.content.hashValue) % 360) / 360
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.35, brightness: 0.45),
                Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1),
                      saturation: 0.25, brightness: 0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func statColumn(title: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statColumn(title: LocalizedStringKey, value: Decimal, color: Color) -> some View {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 1
        let v = f.string(from: NSDecimalNumber(decimal: value)) ?? "¥0"
        return statColumn(title: title, value: v, color: color)
    }
}

// MARK: - 主视图
struct HomeView: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("UserProfileAvatarData") private var avatarData: Data?
    @State private var showProfile = false

    // MARK: - 今日账单数据
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        predicate: NSPredicate(format: "date >= %@ AND date < %@",
                               Calendar.current.startOfDay(for: Date()) as NSDate,
                               Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) as NSDate),
        animation: .default
    ) private var todayBills: FetchedResults<Bill>

    // MARK: - UI State
    @State private var sentences: [DailySentence] = []
    @State private var currentSentence: DailySentence?
    @State private var nextSentence: DailySentence?   // 预加载的下一条
    @State private var isInitialLoading = true
    @State private var isRefreshing = false
    @State private var cardOpacity: Double = 1
    @State private var cardScale: Double = 1
    @State private var rotationAngle: Double = 0

    // 分享相关
    @State private var sharePayload: SharePayload?
    @State private var sharedTempURL: URL?
    @State private var shareError: String?

    // MARK: - 当日统计计算属性
    private var todayIncome: Decimal {
        todayBills.filter { $0.type == "income" }.reduce(Decimal(0)) { $0 + ($1.amount?.decimalValue ?? 0) }
    }

    private var todayExpense: Decimal {
        todayBills.filter { $0.type == "expenditure" }.reduce(Decimal(0)) { $0 + ($1.amount?.decimalValue ?? 0) }
    }

    private var todayBalance: Decimal {
        todayIncome - todayExpense
    }

    private var todayDateText: String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if isInitialLoading {
                            Spacer(minLength: 160)
                            ProgressView().scaleEffect(1.3)
                            Spacer(minLength: 240)
                        } else if let s = currentSentence {
                            Spacer(minLength: 16)

                            // ── 今日结余卡片 ──
                            TodayBalanceCard(
                                income: todayIncome,
                                expense: todayExpense,
                                balance: todayBalance,
                                billCount: todayBills.count
                            )
                            .padding(.horizontal, 20)

                            Spacer(minLength: 16)

                            // ── 名言卡片 ──
                            SentenceCardView(sentence: s, displaySize: cardSize)
                                .id(s.id)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
                                .opacity(cardOpacity)
                                .scaleEffect(cardScale)
                                .padding(.horizontal, 20)

                            Spacer(minLength: 28)

                            // ── 操作按钮 ──
                            HStack(spacing: 48) {
                                Button {
                                    guard !isRefreshing else { return }
                                    HapticManager.shared.medium()
                                    refresh()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 17, weight: .medium))
                                        .rotationEffect(.degrees(rotationAngle))
                                        .frame(width: 50, height: 50)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.8))
                                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                                }
                                .foregroundStyle(.primary)
                                .disabled(isRefreshing)

                                Button {
                                    HapticManager.shared.light()
                                    renderAndShare(s)
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 17, weight: .medium))
                                        .frame(width: 50, height: 50)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.8))
                                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                                }
                                .foregroundStyle(.primary)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Group {
                            if let data = avatarData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 35, height: 35)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 26))
                            }
                        }
                        .foregroundColor(.blue)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("header.edit_profile")
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(item: $sharePayload, onDismiss: {
                if let url = sharedTempURL {
                    try? FileManager.default.removeItem(at: url)
                }
                sharedTempURL = nil
            }) { payload in
                ShareSheet(items: [payload.imageURL])
                    .presentationDetents([.medium, .large])
            }
            .alert(String(localized: "home.share_failed"), isPresented: Binding(
                get: { shareError != nil },
                set: { if !$0 { shareError = nil } }
            )) {
                Button(String(localized: "common.ok")) { shareError = nil }
            } message: {
                Text(shareError ?? "")
            }
            .navigationTitle("home.title")
            .onAppear {
                loadSentences()
            }
        }
    }

    /// 卡片宽度（自适应屏幕）
    private var cardSize: CGSize {
        let screenWidth = min(UIScreen.main.bounds.width, 500) // 限制最大尺寸
        return CGSize(width: screenWidth - 40, height: 500)
    }

    // MARK: - 加载 JSON
    private func loadSentences() {
        guard let url = Bundle.main.url(forResource: "EconomicQuotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([DailySentence].self, from: data)
        else {
            isInitialLoading = false
            return
        }
        sentences = list
        currentSentence = list.randomElement()
        isInitialLoading = false

        // 首次加载后立即预加载下一条
        Task { await prepareNext() }
    }

    // MARK: - 预加载下一条图片
    private func prepareNext() async {
        let filtered = sentences.filter { $0.id != currentSentence?.id }
        guard let next = (filtered.isEmpty ? sentences : filtered).randomElement() else { return }
        nextSentence = next

        let seed = abs(next.content.hashValue) % 1000
        guard let url = URL(string: "https://picsum.photos/seed/\(seed)/800/1200") else { return }

        let loader = ImageLoader()
        await loader.preload(url: url)
    }

    // MARK: - 刷新
    private func refresh() {
        guard sentences.count > 1 else { return }
        isRefreshing = true

        // 刷新按钮转一圈
        withAnimation(.linear(duration: 0.45)) { rotationAngle += 360 }

        // 卡片淡出缩小
        withAnimation(.easeIn(duration: 0.20)) {
            cardOpacity = 0
            cardScale = 0.95
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            // 切换到已预加载的下一条（图片已在缓存中）
            if let next = nextSentence {
                currentSentence = next
            } else {
                let filtered = sentences.filter { $0.id != currentSentence?.id }
                currentSentence = (filtered.isEmpty ? sentences : filtered).randomElement()
            }
            nextSentence = nil

            // 卡片弹入
            withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                cardOpacity = 1
                cardScale = 1
            }
            isRefreshing = false

            // 后台预加载再下一条
            Task { await prepareNext() }
        }
    }

    // MARK: - 渲染分享卡片（含当日统计数据）
    @MainActor
    private func renderAndShare(_ sentence: DailySentence) {
        // 先获取当前已加载的图片（用于分享卡片渲染）
        let cardWidth: CGFloat = 375
        let imageAreaHeight = cardWidth / 0.75 // 图片区域高度（与首页一致）
        let statAreaHeight: CGFloat = 180      // 统计区域估算高度
        let totalHeight = imageAreaHeight + statAreaHeight

        let renderer = ImageRenderer(
            content: ShareCardView(
                sentence: sentence,
                backgroundImage: getCurrentCardImage(),
                dailyBalance: todayBalance,
                incomeTotal: todayIncome,
                expenseTotal: todayExpense,
                billCount: todayBills.count,
                dateText: todayDateText
            )
            .frame(width: cardWidth, height: totalHeight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        renderer.scale = displayScale

        guard let image = renderer.uiImage else {
            shareError = L10n.string("home.share_error_render")
            return
        }

        guard let data = image.jpegData(compressionQuality: 0.92) else {
            shareError = L10n.string("home.share_error_encode")
            return
        }

        let fileName = "iFinance-\(todayDateText)-\(UUID().uuidString.prefix(6)).jpg"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            sharedTempURL = fileURL
            sharePayload = SharePayload(imageURL: fileURL)
        } catch {
            shareError = String(format: L10n.string("home.share_error_write"), error.localizedDescription)
        }
    }

    /// 获取当前卡片的图片（供分享使用）
    private func getCurrentCardImage() -> UIImage? {
        // 通过 ImageCache 获取当前句子的缓存图片
        guard let s = currentSentence else { return nil }
        let seed = abs(s.content.hashValue) % 1000
        let urlString = "https://picsum.photos/seed/\(seed)/800/1200"

        // 尝试获取更高分辨率的图片用于分享
        return ImageCache.shared.get(urlString) ?? ImageCache.shared.getFromDisk(urlString)
    }
}

// MARK: - 分享 Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - 预览
#Preview {
    HomeView()
}
