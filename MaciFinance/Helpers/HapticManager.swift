//
//  HapticManager.swift
//  MaciFinance
//
//  macOS 触感反馈辅助（NSHapticFeedbackManager 封装）
//

import AppKit

/// 触感反馈管理器（macOS 单例）
final class HapticManager {

    static let shared = HapticManager()

    /// 轻微触碰 — 列表选择、次要操作
    func light() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }

    /// 中等触碰 — 开关切换、导航选择
    func medium() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }

    /// 强烈触碰 — 重要操作确认
    func heavy() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    /// 成功反馈
    func success() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }

    /// 错误反馈
    func error() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }

    /// 选择变化 — Segmented / Picker
    func selectionChanged() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }

    private init() {}
}
