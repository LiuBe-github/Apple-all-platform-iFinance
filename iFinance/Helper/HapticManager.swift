//
//  HapticManager.swift
//  iFinance
//
//  触感反馈管理器 — 统一管理所有触感反馈调用
//  支持 iOS (UIKit) 和 macOS (空实现，macOS 使用系统默认触感)
//

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 触感反馈管理器（单例）
final class HapticManager {

    static let shared = HapticManager()

    // MARK: - Impact（碰撞/点击类）

    /// 轻微触碰 — 用于数字键盘按键、列表选择等高频轻量操作
    func light() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    /// 中等触碰 — 用于开关切换、Tab 切换、按钮确认等常规交互
    func medium() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #elseif os(macOS)
        // macOS: 使用 NSHapticFeedbackManager 的性能反馈
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
    }

    /// 强烈触碰 — 用于重要操作确认（保存、删除、完成记账等）
    func heavy() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        #endif
    }

    /// 柔性触碰 — 用于拖拽、滑动等连续交互
    func soft() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    /// 刚性触碰 — 用于边界碰撞、错误输入等
    func rigid() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    // MARK: - Notification（通知类）

    /// 成功通知 ✅ — 操作成功完成
    func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        #endif
    }

    /// 警告通知 ⚠️ — 需要注意但不致命
    func warning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }

    /// 错误通知 ❌ — 操作失败、输入无效等
    func error() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
    }

    // MARK: - SelectionChanged（选择变化）

    /// 选择改变 — 用于 Picker、Segmented 等选择控件
    func selectionChanged() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    private init() {}
}
