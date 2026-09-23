//
//  AppVisualStyle.swift
//  MaciFinance
//
//  macOS 视觉样式组件
//

import SwiftUI
import AppKit

/// 应用背景视图（macOS版本，含呼吸光斑）
struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                baseGradient
                floatingOrb(color: .blue, opacity: colorScheme == .dark ? 0.20 : 0.10,
                            size: 300, baseOffset: CGPoint(x: -220, y: -260), drift: 16, speed: 0.15, phase: 0, time: t)
                floatingOrb(color: .cyan, opacity: colorScheme == .dark ? 0.14 : 0.08,
                            size: 240, baseOffset: CGPoint(x: 260, y: -200), drift: 18, speed: 0.11, phase: 2.1, time: t)
                floatingOrb(color: .pink, opacity: colorScheme == .dark ? 0.12 : 0.06,
                            size: 280, baseOffset: CGPoint(x: 220, y: 320), drift: 20, speed: 0.09, phase: 4.2, time: t)
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

    private func floatingOrb(color: Color, opacity: Double, size: CGFloat,
                             baseOffset: CGPoint, drift: CGFloat, speed: Double,
                             phase: Double, time: Double) -> some View {
        let dx = sin(time * speed + phase) * drift
        let dy = cos(time * speed * 0.8 + phase) * drift
        return Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 40)
            .offset(x: baseOffset.x + dx, y: baseOffset.y + dy)
    }
}

// MARK: - View 扩展

extension View {
    /// 毛玻璃卡片样式
    func appGlassCard(cornerRadius: CGFloat = 22) -> some View {
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
                    .shadow(color: .black.opacity(0.07), radius: 18, x: 0, y: 10)
            }
    }

    /// macOS 标准卡片（controlBackground + 描边 + 阴影）
    func macCard(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    /// 悬停抬升（macOS 交互反馈）
    func macHoverLift(_ isHovering: Bool, lift: CGFloat = -2) -> some View {
        self
            .offset(y: isHovering ? lift : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
    }

    /// 数字滚动过渡
    func appNumericTransition(value: Double) -> some View {
        self
            .contentTransition(.numericText(value: value))
            .animation(.snappy(duration: 0.35), value: value)
    }
}

// MARK: - 按压缩放按钮样式

struct ScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
