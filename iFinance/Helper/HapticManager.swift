//
//  HapticManager.swift
//  iFinance
//
//  触感反馈管理器 — 统一管理所有 UIImpactFeedbackGenerator / UINotificationFeedbackGenerator 调用
//

import UIKit

/// 触感反馈管理器（单例）
final class HapticManager {

    static let shared = HapticManager()

    // MARK: - Impact（碰撞/点击类）

    /// 轻微触碰 — 用于数字键盘按键、列表选择等高频轻量操作
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 中等触碰 — 用于开关切换、Tab 切换、按钮确认等常规交互
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 强烈触碰 — 用于重要操作确认（保存、删除、完成记账等）
    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 柔性触碰 — 用于拖拽、滑动等连续交互
    func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 刚性触碰 — 用于边界碰撞、错误输入等
    func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Notification（通知类）

    /// 成功通知 ✅ — 操作成功完成
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// 警告通知 ⚠️ — 需要注意但不致命
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// 错误通知 ❌ — 操作失败、输入无效等
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    // MARK: - SelectionChanged（选择变化）

    /// 选择改变 — 用于 Picker、Segmented 等选择控件
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    private init() {}
}
