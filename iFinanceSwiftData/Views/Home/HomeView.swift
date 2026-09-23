//
//  HomeView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI
import Combine
import UIKit
import SwiftData

// MARK: - 分享数据载体
private struct SharePayload: Identifiable {
    let id = UUID()
    let imageURL: URL
}

// MARK: - 主视图
struct HomeView: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var authManager: AuthManager
    @State private var showProfile = false

    // MARK: - 今日账单数据
    @Query(filter: PersistenceController.billUserPredicate, sort: \Bill.date, order: .reverse, animation: .default)
    private var userBills: [Bill]

    /// 今日账单（SwiftData 版：先按用户查询，再在内存中过滤当天）
    private var todayBills: [Bill] {
        let calendar = Calendar.current
        return userBills.filter { bill in
            guard let date = bill.date else { return false }
            return calendar.isDate(date, inSameDayAs: Date())
        }
    }

    // MARK: - UI State
    @State private var sentences: [DailySentence] = []
    @State private var currentSentence: DailySentence?
    @State private var nextSentence: DailySentence?   // 预加载的下一条
    @State private var isInitialLoading = true
    @State private var isRefreshing = false
    @State private var cardOpacity: Double = 1
    @State private var cardScale: Double = 1
    @State private var refreshAngle: Double = 0
    @State private var shareBounceTrigger = 0
    @State private var contentVisible = false

    // 分享相关
    @State private var sharePayload: SharePayload?
    @State private var sharedTempURL: URL?
    @State private var shareError: String?

    // MARK: - 当日统计计算属性
    private var todayIncome: Decimal {
        todayBills.filter { $0.type == "income" }.reduce(Decimal(0)) { $0 + ($1.amount ?? 0) }
    }

    private var todayExpense: Decimal {
        todayBills.filter { $0.type == "expenditure" }.reduce(Decimal(0)) { $0 + ($1.amount ?? 0) }
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

                            // 今日结余卡片
                            TodayBalanceCard(
                                income: todayIncome,
                                expense: todayExpense,
                                balance: todayBalance,
                                billCount: todayBills.count
                            )
                            .padding(.horizontal, AppSpacing.screen)
                            .transition(AppMotion.resolvedTransition(AppMotion.riseIn, reduceMotion: reduceMotion))

                            Spacer(minLength: AppSpacing.lg)

                            // 名言卡片
                            SentenceCardView(sentence: s, displaySize: cardSize)
                                .id(s.id)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sheet, style: .continuous))
                                .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
                                .opacity(cardOpacity)
                                .scaleEffect(cardScale)
                                .padding(.horizontal, AppSpacing.xl)

                            Spacer(minLength: AppSpacing.xxl)

                            // 操作按钮
                            HStack(spacing: AppSpacing.section) {
                                Button {
                                    guard !isRefreshing else { return }
                                    HapticManager.shared.medium()
                                    refresh()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 17, weight: .medium))
                                        .rotationEffect(.degrees(refreshAngle))
                                        .frame(width: 50, height: 50)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.8))
                                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                                }
                                .foregroundStyle(.primary)
                                .disabled(isRefreshing)
                                .buttonStyle(ScaleButtonStyle())

                                Button {
                                    HapticManager.shared.light()
                                    shareBounceTrigger += 1
                                    renderAndShare(s)
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 17, weight: .medium))
                                        .frame(width: 50, height: 50)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.8))
                                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                                        .symbolEffect(.bounce, value: shareBounceTrigger)
                                }
                                .foregroundStyle(.primary)
                                .buttonStyle(ScaleButtonStyle())
                            }
                            .padding(.bottom, AppSpacing.xl)
                            .opacity(cardOpacity)
                        }
                    }
                    .appContentWidth()
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Group {
                            if let data = authManager.avatarData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.title.bold())
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
        CGSize(width: AppLayout.contentMaxWidth - AppSpacing.screen * 2,
               height: AppLayout.heroImageMaxHeight)
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

        // 首次加载完成后的入场动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(AppMotion.resolved(AppMotion.emphasized, reduceMotion: reduceMotion)) {
                contentVisible = true
            }
        }

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
        withAnimation(AppMotion.resolved(AppMotion.ambient, reduceMotion: reduceMotion)) { refreshAngle += 360 }

        // 卡片淡出缩小
        withAnimation(AppMotion.resolved(AppMotion.quick, reduceMotion: reduceMotion)) {
            cardOpacity = 0
            cardScale = 0.94
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            // 切换到已预加载的下一条（图片已在缓存中）
            if let next = nextSentence {
                currentSentence = next
            } else {
                let filtered = sentences.filter { $0.id != currentSentence?.id }
                currentSentence = (filtered.isEmpty ? sentences : filtered).randomElement()
            }
            nextSentence = nil

            // 卡片弹入
            withAnimation(AppMotion.resolved(AppMotion.emphasized, reduceMotion: reduceMotion)) {
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
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sheet, style: .continuous))
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

#Preview {
    HomeView()
}
