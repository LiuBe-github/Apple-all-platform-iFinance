//
//  NotificationManager.swift
//  iFinance
//
//  本地通知管理器（已暂时禁用，需付费开发者账号才能使用推送通知）
//  类结构保留以保证编译通过，所有通知相关调用已注释
//

import Foundation
import Combine
// import UserNotifications  // 暂时禁用
internal import CoreData

// MARK: - 通知类型

enum NotificationType: String, CaseIterable {
    /// 预算超支提醒
    case budgetExceeded = "budget_exceeded"
    /// 记账提醒
    case reminder = "reminder"
    /// 每日账单汇总
    case dailySummary = "daily_summary"

    var categoryIdentifier: String { rawValue }

    var titleKey: String {
        switch self {
        case .budgetExceeded: return "notification.budget_exceeded.title"
        case .reminder:       return "notification.reminder.title"
        case .dailySummary:    return "notification.daily_summary.title"
        }
    }

    var bodyKey: String {
        switch self {
        case .budgetExceeded: return "notification.budget_exceeded.body"
        case .reminder:       return "notification.reminder.body"
        case .dailySummary:    return "notification.daily_summary.body"
        }
    }
}

// MARK: - 通知管理器（Stub 版本）

@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    // MARK: - Published State

    /// 通知权限状态（暂时禁用，固定为 notDetermined）
    @Published private(set) var isPermissionRequested: Bool = false

    /// App Badge 数量（暂时禁用）
    @Published var badgeCount: Int = 0

    // MARK: - Init

    override private init() {
        super.init()
        // 通知功能已暂时禁用
    }

    // MARK: - Public API（均为空实现）

    /// 请求通知权限（暂时禁用）
    func requestAuthorization() async -> Bool {
        return false
    }

    /// 刷新权限状态（暂时禁用）
    func refreshAuthorizationStatus() {}

    /// 移除所有待发送的本地通知（暂时禁用）
    func removeAllPendingNotifications() {}

    /// 移除所有已展示的通知（暂时禁用）
    func removeAllDeliveredNotifications() {}

    /// 移除指定类型的待发送通知（暂时禁用）
    func removePendingNotifications(for type: NotificationType) {}

    /// 发送预算超支提醒（暂时禁用）
    func scheduleBudgetExceededNotification(spent: Double, budget: Double, category: String?) async {}

    /// 发送记账提醒（暂时禁用）
    func scheduleDailyReminderNotification(at hour: Int, minute: Int) async {}

    /// 发送每日账单汇总（暂时禁用）
    func scheduleDailySummaryNotification(at hour: Int, minute: Int) async {}
}

// MARK: - Notification Names

extension Notification.Name {
    static let didRequestAddBill    = Notification.Name("didRequestAddBill")
    static let didRequestBudgetView  = Notification.Name("didRequestBudgetView")
}
