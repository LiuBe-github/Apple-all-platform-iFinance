//
//  SentenceCardView.swift
//  iFinance
//
//  名言卡片视图（用于首页展示）
//

import SwiftUI

/// 名言卡片视图（用于首页展示）
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

#Preview {
    SentenceCardView(sentence: DailySentence(
        content: "风险来自于你不知道自己在做什么。",
        note: "沃伦·巴菲特",
        picture2: ""
    ))
    .frame(height: 400)
}
