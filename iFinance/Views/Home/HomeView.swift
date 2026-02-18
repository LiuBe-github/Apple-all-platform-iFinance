//
//  HomeView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI
import Combine

// MARK: - 图片缓存（内存级，进程内复用）
private final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() {
        cache.countLimit  = 30
        cache.totalCostLimit = 1024 * 1024 * 80  // 80 MB
    }
    
    func get(_ key: String) -> UIImage?          { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, for key: String)  { cache.setObject(image, forKey: key as NSString) }
}

// MARK: - 图片加载器
@MainActor
private final class ImageLoader: ObservableObject {
    @Published var image:    UIImage?
    @Published var isLoaded: Bool = false
    
    private var currentURL: URL?
    
    func load(url: URL) {
        // 命中缓存直接返回，不产生任何网络请求
        if let cached = ImageCache.shared.get(url.absoluteString) {
            self.image    = cached
            self.isLoaded = true
            return
        }
        
        currentURL = url
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let uiImage = UIImage(data: data),
                      url == currentURL           // 防止旧请求覆盖新结果
                else { return }
                
                ImageCache.shared.set(uiImage, for: url.absoluteString)
                self.image    = uiImage
                self.isLoaded = true
            } catch {
                // 加载失败时不改变状态，卡片显示兜底渐变
            }
        }
    }
    
    /// 异步加载并返回图片（供预加载使用）
    func preload(url: URL) async {
        guard ImageCache.shared.get(url.absoluteString) == nil else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return }
        ImageCache.shared.set(uiImage, for: url.absoluteString)
    }
}

// MARK: - 名言卡片
struct SentenceCardView: View {
    let sentence: DailySentence
    
    @StateObject private var loader = ImageLoader()
    
    private var imageURL: URL? {
        let seed = abs(sentence.content.hashValue) % 1000
        return URL(string: "https://picsum.photos/seed/\(seed)/800/1200")
    }
    
    /// 失败兜底渐变（基于哈希，固定色调）
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
            let h = geo.size.height
            
            ZStack(alignment: .bottomLeading) {
                
                // ── 背景：缓存图 / 骨架屏 / 兜底渐变 ──
                Group {
                    if let img = loader.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity.animation(.easeIn(duration: 0.25)))
                    } else if !loader.isLoaded {
                        // 骨架屏（加载中）
                        ZStack {
                            Color(UIColor.systemGray5)
                            ProgressView().tint(Color(UIColor.systemGray2))
                        }
                    } else {
                        // 加载失败兜底
                        fallbackGradient
                    }
                }
                .frame(width: w, height: h)
                .clipped()
                
                // ── 底部渐变遮罩 ──
                LinearGradient(
                    stops: [
                        .init(color: .clear,               location: 0.0),
                        .init(color: .black.opacity(0.12), location: 0.42),
                        .init(color: .black.opacity(0.70), location: 0.76),
                        .init(color: .black.opacity(0.86), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
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
                        Text("— \(sentence.note)")
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
        .onAppear {
            guard let url = imageURL else { return }
            loader.load(url: url)
        }
    }
}

// MARK: - 主视图
struct HomeView: View {
    @State private var sentences: [DailySentence] = []
    @State private var currentSentence: DailySentence?
    @State private var nextSentence: DailySentence?   // 预加载的下一条
    @State private var isInitialLoading = true
    @State private var isRefreshing = false
    @State private var cardOpacity: Double = 1
    @State private var cardScale: Double = 1
    @State private var rotationAngle: Double = 0
    
    // 分享
    @State private var shareImage: UIImage?
    
    private let cardWidth:  CGFloat = UIScreen.main.bounds.width - 40
    private let cardHeight: CGFloat = 500
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isInitialLoading {
                    Spacer()
                    ProgressView().scaleEffect(1.3)
                    Spacer()
                } else if let s = currentSentence {
                    Spacer(minLength: 16)
                    
                    // ── 名言卡片 ──
                    SentenceCardView(sentence: s)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
                        .opacity(cardOpacity)
                        .scaleEffect(cardScale)
                    
                    Spacer(minLength: 28)
                    
                    // ── 操作按钮 ──
                    HStack(spacing: 48) {
                        // 刷新
                        Button {
                            guard !isRefreshing else { return }
                            refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 17, weight: .medium))
                                .rotationEffect(.degrees(rotationAngle))
                                .frame(width: 50, height: 50)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                        .foregroundStyle(.primary)
                        .disabled(isRefreshing)
                        
                        // 分享
                        Button {
                            renderAndShare(sentence: s)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .medium))
                                .frame(width: 50, height: 50)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                        .foregroundStyle(.primary)
                    }
                    .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HeaderView(isTransactionView: false)
                }
            }
            .sheet(item: $shareImage) { image in
                ShareSheet(items: [image])
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                loadSentences()
            }
        }
    }
    
    // MARK: - 加载 JSON
    private func loadSentences() {
        guard let url  = Bundle.main.url(forResource: "EconomicQuotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([DailySentence].self, from: data)
        else {
            isInitialLoading = false
            return
        }
        sentences       = list
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
        await loader.preload(url: url)  // 下载并写入 NSCache
    }
    
    // MARK: - 刷新
    private func refresh() {
        guard sentences.count > 1 else { return }
        isRefreshing = true
        
        // 刷新按钮转一圈
        withAnimation(.linear(duration: 0.45)) {
            rotationAngle += 360
        }
        
        // 卡片淡出缩小
        withAnimation(.easeIn(duration: 0.20)) {
            cardOpacity = 0
            cardScale   = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            // 切换到已预加载的下一条（图片已在 NSCache，无需等待网络）
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
                cardScale   = 1
            }
            isRefreshing = false
            
            // 后台预加载再下一条
            Task { await prepareNext() }
        }
    }
    
    // MARK: - 分享
    @MainActor
    private func renderAndShare(sentence: DailySentence) {
        let renderer = ImageRenderer(
            content: SentenceCardView(sentence: sentence)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
        renderer.scale = UIScreen.main.scale
        if let img = renderer.uiImage { shareImage = img }
    }
}

// MARK: - UIImage Identifiable
extension UIImage: @retroactive Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
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
#Preview { HomeView() }
