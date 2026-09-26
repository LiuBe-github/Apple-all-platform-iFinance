//
//  TodoModels.swift
//  iFinance
//
//  待办与备忘的**纯逻辑**（分组 / 排序 / 重复规则推进），不依赖具体数据栈，
//  因此 Core Data 版与 SwiftData 版共用同一份实现与同一批单测。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation

// MARK: - 轻量快照

/// 待办的只读快照（视图与纯函数共用；避免纯逻辑依赖 `@FetchRequest` / `@Query` 的具体类型）
struct TodoSnapshot: Equatable, Identifiable {
    let id: UUID
    let title: String
    let note: String?
    let dueDate: Date?
    /// 0 = 无、1 = 低、2 = 中、3 = 高（与 Core Data `Integer 16` 生成类型一致）
    let priority: Int16
    let isDone: Bool
    let repeatRule: String
    let createdAt: Date
}

// MARK: - 优先级

enum TodoPriority {
    static let none: Int16 = 0
    static let low: Int16 = 1
    static let medium: Int16 = 2
    static let high: Int16 = 3

    static let all: [Int16] = [none, low, medium, high]

    /// 列表内的排序权重（高优先级靠前）
    static func sortWeight(_ priority: Int16) -> Int {
        Int(high - min(max(priority, none), high))
    }

    static func localizedKey(_ priority: Int16) -> String {
        switch priority {
        case low: return "todo.priority.low"
        case medium: return "todo.priority.medium"
        case high: return "todo.priority.high"
        default: return "todo.priority.none"
        }
    }
}

// MARK: - 分组

enum TodoGroup: String, CaseIterable {
    case overdue
    case today
    case nextSevenDays
    case later
    case noDate
    case completed

    var localizedKey: String { "todo.group.\(rawValue)" }
}

enum TodoGrouping {

    /// 未来 7 天的判定窗口（today + 7 天，含边界当天）
    static let upcomingWindowDays = 7

    static func group(of item: TodoSnapshot, now: Date = Date(), calendar: Calendar = .current) -> TodoGroup {
        guard !item.isDone else { return .completed }
        guard let dueDate = item.dueDate else { return .noDate }

        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        if dueDay < today { return .overdue }
        if dueDay == today { return .today }
        if let windowEnd = calendar.date(byAdding: .day, value: upcomingWindowDays, to: today),
           dueDay <= windowEnd {
            return .nextSevenDays
        }
        return .later
    }

    /// 按固定顺序返回非空分组（逾期 → 今天 → 未来 7 天 → 以后 → 无日期 → 已完成）
    static func grouped(
        _ items: [TodoSnapshot],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(group: TodoGroup, items: [TodoSnapshot])] {
        TodoGroup.allCases.compactMap { group in
            let matched = items.filter { self.group(of: $0, now: now, calendar: calendar) == group }
            guard !matched.isEmpty else { return nil }
            return (group, sorted(matched, in: group, calendar: calendar))
        }
    }

    /// 组内排序：优先未完成、优先级高在前、截止日近在前（无日期最末）、创建时间近在前
    static func sorted(_ items: [TodoSnapshot], in group: TodoGroup, calendar: Calendar = .current) -> [TodoSnapshot] {
        if group == .completed {
            return items.sorted { $0.createdAt > $1.createdAt }
        }
        return items.sorted { lhs, rhs in
            let lhsWeight = TodoPriority.sortWeight(lhs.priority)
            let rhsWeight = TodoPriority.sortWeight(rhs.priority)
            if lhsWeight != rhsWeight { return lhsWeight < rhsWeight }

            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?):
                if l != r { return l < r }
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            default:
                break
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

// MARK: - 重复规则

enum TodoRepeat {
    static let noneRule = "none"
    static let daily = "daily"
    static let weekly = "weekly"
    static let monthly = "monthly"
    static let yearly = "yearly"

    static let all: [String] = [noneRule, daily, weekly, monthly, yearly]

    static func localizedKey(_ rule: String) -> String {
        "todo.repeat.\(all.contains(rule) ? rule : noneRule)"
    }

    /// 完成后生成下一期的时间点；`none` 返回 nil。
    /// 月末 / 闰年由 `Calendar` 自动收敛（1 月 31 日 + 1 个月 = 2 月 28/29 日）。
    static func nextDueDate(after date: Date, rule: String, calendar: Calendar = .current) -> Date? {
        switch rule {
        case daily: return calendar.date(byAdding: .day, value: 1, to: date)
        case weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case yearly: return calendar.date(byAdding: .year, value: 1, to: date)
        default: return nil
        }
    }
}

// MARK: - 备忘排序

enum MemoSorting {
    /// 置顶优先，其次按更新时间倒序
    static func sorted(_ memos: [(id: UUID, isPinned: Bool, updatedAt: Date)]) -> [UUID] {
        memos
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }
            .map(\.id)
    }
}

// MARK: - 标签规则

/// 重复待办完成后的「下一期」推进（纯数据，视图只负责落库与复制关系）
enum TodoRecurrence {

    /// 生成下一期草稿：截止日按重复规则推进，其余字段沿用，完成状态重置。
    /// 不重复、无截止日或规则非法时返回 nil。
    static func nextDraft(
        after snapshot: TodoSnapshot,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TodoSnapshot? {
        guard snapshot.repeatRule != TodoRepeat.noneRule,
              let dueDate = snapshot.dueDate,
              let nextDueDate = TodoRepeat.nextDueDate(after: dueDate, rule: snapshot.repeatRule, calendar: calendar) else {
            return nil
        }

        return TodoSnapshot(
            id: UUID(),
            title: snapshot.title,
            note: snapshot.note,
            dueDate: nextDueDate,
            priority: snapshot.priority,
            isDone: false,
            repeatRule: snapshot.repeatRule,
            createdAt: now
        )
    }
}

/// 待办标签的名字与数量规则（视图与单测共用）
enum TodoTagRules {

    /// 每账号标签上限
    static let maxCount = 12
    /// 标签名长度上限（按字符数）
    static let maxNameLength = 8

    enum Validation: Equatable {
        case valid
        case empty
        case tooLong
        case duplicate
        case limit
    }

    /// 校验标签名：去空白后 1–8 字、不与既有标签重名（忽略大小写与音标差异）
    static func validate(_ rawName: String, existingNames: [String]) -> Validation {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .empty }
        guard name.count <= maxNameLength else { return .tooLong }

        let duplicated = existingNames.contains { existing in
            existing.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        return duplicated ? .duplicate : .valid
    }

    /// 是否还能新增标签
    static func canAdd(existingCount: Int) -> Bool {
        existingCount < maxCount
    }
}
