//
//  AppMotion.swift
//  iFinance
//
//  统一动画 token：三档节奏 + 数字档，并统一支持「减弱动态效果」降级。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

enum AppMotion {
    /// 快速档：按压、高亮、开关、轻量状态切换
    static let quick: Animation = .easeOut(duration: 0.18)
    /// 标准档：列表增删、筛选/分段切换、图表切换、错误提示
    static let standard: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    /// 强调档：卡片与页面内容入场
    static let emphasized: Animation = .spring(response: 0.5, dampingFraction: 0.82)
    /// 数字档：金额数字滚动
    static let numeric: Animation = .snappy(duration: 0.35)
    /// 循环档：微光骨架屏
    static let shimmer: Animation = .linear(duration: 1.4).repeatForever(autoreverses: false)
    /// 按压回弹
    static let press: Animation = .spring(response: 0.3, dampingFraction: 0.7)
    /// 呼吸光斑 / 长时间漂移
    static let ambient: Animation = .easeInOut(duration: 0.5)

    /// Reduce Motion 时的替代动画
    static let reduced: Animation = .easeOut(duration: 0.15)

    /// 错峰入场延迟：min(index, 8) × 40ms
    static func entranceDelay(index: Int) -> Double {
        Double(min(max(index, 0), 8)) * 0.04
    }

    /// 按「减弱动态效果」开关解析动画
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }

    /// 按「减弱动态效果」开关解析位移类转场（退化为纯淡入淡出）
    static func resolvedTransition(_ transition: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }

    /// 通用「从下方浮入」转场
    static let riseIn: AnyTransition = .move(edge: .bottom).combined(with: .opacity)
}

// MARK: - 统一动画修饰器

private struct AppAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(AppMotion.resolved(animation, reduceMotion: reduceMotion), value: value)
    }
}

private struct AppEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let index: Int
    let visible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 14)
            .animation(
                AppMotion.resolved(AppMotion.emphasized, reduceMotion: reduceMotion)
                    .delay(reduceMotion ? 0 : AppMotion.entranceDelay(index: index)),
                value: visible
            )
    }
}

extension View {
    /// 统一的动画挂载点（自动遵循「减弱动态效果」）
    func appAnimation<V: Equatable>(_ animation: Animation = AppMotion.standard, value: V) -> some View {
        modifier(AppAnimationModifier(animation: animation, value: value))
    }

    /// 错峰入场（淡入 + 轻微上移），自动遵循「减弱动态效果」
    func appEntrance(index: Int = 0, visible: Bool = true) -> some View {
        modifier(AppEntranceModifier(index: index, visible: visible))
    }

    /// 统一按压反馈样式（等价 `.buttonStyle(.scalePress)`）
    func appPressable() -> some View {
        buttonStyle(ScaleButtonStyle())
    }
}
