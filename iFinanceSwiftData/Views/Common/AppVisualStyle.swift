import SwiftUI

// MARK: - 应用背景（渐变 + 呼吸光斑）

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                baseGradient

                // 光斑随时间缓慢漂移，营造"呼吸感"
                floatingOrb(
                    color: .blue,
                    opacity: colorScheme == .dark ? 0.22 : 0.12,
                    size: 260,
                    baseOffset: CGPoint(x: -120, y: -300),
                    drift: 14,
                    speed: 0.18,
                    phase: 0,
                    time: t
                )
                floatingOrb(
                    color: .cyan,
                    opacity: colorScheme == .dark ? 0.16 : 0.10,
                    size: 220,
                    baseOffset: CGPoint(x: 130, y: -210),
                    drift: 18,
                    speed: 0.13,
                    phase: 2.1,
                    time: t
                )
                floatingOrb(
                    color: .pink,
                    opacity: colorScheme == .dark ? 0.14 : 0.08,
                    size: 260,
                    baseOffset: CGPoint(x: 100, y: 360),
                    drift: 20,
                    speed: 0.11,
                    phase: 4.2,
                    time: t
                )
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    private var baseGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.14),
                    Color(red: 0.10, green: 0.09, blue: 0.14),
                    Color(red: 0.06, green: 0.11, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.97, blue: 1.0),
                Color(red: 0.97, green: 0.95, blue: 0.99),
                Color(red: 0.95, green: 0.99, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func floatingOrb(
        color: Color,
        opacity: Double,
        size: CGFloat,
        baseOffset: CGPoint,
        drift: CGFloat,
        speed: Double,
        phase: Double,
        time: Double
    ) -> some View {
        let dx = sin(time * speed + phase) * drift
        let dy = cos(time * speed * 0.8 + phase) * drift
        return Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 36)
            .offset(x: baseOffset.x + dx, y: baseOffset.y + dy)
    }
}

// MARK: - View 扩展

extension View {
    /// 毛玻璃卡片样式（统一三端视觉语言）
    func appGlassCard(cornerRadius: CGFloat = AppRadius.card) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.55), .white.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
                    .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 8)
            }
    }

    /// 柔和的次级阴影（用于非玻璃卡片）
    func appSoftShadow() -> some View {
        self.shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    /// 数字滚动过渡（金额变化时平滑滚动）
    func appNumericTransition(value: Double) -> some View {
        self
            .contentTransition(.numericText(value: value))
            .animation(AppMotion.numeric, value: value)
    }
}

// MARK: - 按压缩放按钮样式（HIG：即时反馈）

struct ScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(AppMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    /// 通用按压反馈样式
    static var scalePress: ScaleButtonStyle { ScaleButtonStyle() }
}

// MARK: - 骨架屏微光

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.35),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: geo.size.width * 0.6)
            .offset(x: phase * geo.size.width * 1.6)
            .onAppear {
                withAnimation(AppMotion.shimmer) {
                    phase = 1
                }
            }
        }
    }
}

// MARK: - 渐变图标底（图标容器）

extension View {
    /// 圆形渐变图标底
    func appIconTile(_ color: Color, size: CGFloat = 40) -> some View {
        self
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.22), color.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Circle().strokeBorder(color.opacity(0.18), lineWidth: 0.8))
            )
    }
}
