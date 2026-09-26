//
//  TodoAssetTests.swift
//  iFinanceSwiftDataTests
//
//  M1 回归（SwiftData 版）：纯逻辑（分组 / 重复 / 占比）与账号隔离 + 删除联动。
//

import Testing
import Foundation
import SwiftData
@testable import iFinanceSwiftData

// MARK: - 纯逻辑

struct TodoLogicTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    private func snapshot(due: Date?, priority: Int16 = 0, isDone: Bool = false, createdAt: Date = Date()) -> TodoSnapshot {
        TodoSnapshot(id: UUID(), title: "t", note: nil, dueDate: due, priority: priority,
                     isDone: isDone, repeatRule: TodoRepeat.noneRule, createdAt: createdAt)
    }

    @Test
    func groupingBuckets() {
        let now = date(2026, 6, 15, 10)
        #expect(TodoGrouping.group(of: snapshot(due: date(2026, 6, 14)), now: now, calendar: calendar) == .overdue)
        #expect(TodoGrouping.group(of: snapshot(due: date(2026, 6, 15, 23)), now: now, calendar: calendar) == .today)
        #expect(TodoGrouping.group(of: snapshot(due: date(2026, 6, 22)), now: now, calendar: calendar) == .nextSevenDays)
        #expect(TodoGrouping.group(of: snapshot(due: date(2026, 6, 23)), now: now, calendar: calendar) == .later)
        #expect(TodoGrouping.group(of: snapshot(due: nil), now: now, calendar: calendar) == .noDate)
        #expect(TodoGrouping.group(of: snapshot(due: date(2026, 6, 14), isDone: true), now: now, calendar: calendar) == .completed)
    }

    @Test
    func repeatRulesAdvanceAndClampMonthEnd() {
        let base = date(2026, 6, 15)
        #expect(TodoRepeat.nextDueDate(after: base, rule: TodoRepeat.daily, calendar: calendar) == date(2026, 6, 16))
        #expect(TodoRepeat.nextDueDate(after: base, rule: TodoRepeat.monthly, calendar: calendar) == date(2026, 7, 15))
        #expect(TodoRepeat.nextDueDate(after: base, rule: TodoRepeat.noneRule, calendar: calendar) == nil)

        let jan31 = date(2026, 1, 31)
        let feb = TodoRepeat.nextDueDate(after: jan31, rule: TodoRepeat.monthly, calendar: calendar)
        #expect(calendar.component(.day, from: feb ?? jan31) == 28)

        let leapJan31 = date(2028, 1, 31)
        let leapFeb = TodoRepeat.nextDueDate(after: leapJan31, rule: TodoRepeat.monthly, calendar: calendar)
        #expect(calendar.component(.day, from: leapFeb ?? leapJan31) == 29)
    }

    @Test
    func memoSortingPinsFirst() {
        let a = UUID(), b = UUID()
        let sorted = MemoSorting.sorted([
            (id: a, isPinned: false, updatedAt: date(2026, 6, 10)),
            (id: b, isPinned: true, updatedAt: date(2026, 6, 1))
        ])
        #expect(sorted == [b, a])
    }

    @Test
    func assetBreakdown() {
        func account(_ type: AssetType, _ balance: Double, include: Bool = true) -> AssetAccountSnapshot {
            AssetAccountSnapshot(id: UUID(), name: "n", type: type, balance: balance, note: nil,
                                 includeInTotal: include, sortOrder: 0)
        }
        let accounts = [
            account(.cash, 1_000),
            account(.investment, 20_000),
            account(.creditCard, -2_000),
            account(.other, 500, include: false)
        ]
        #expect(AssetBreakdown.totalAssets(accounts) == 21_000)
        #expect(AssetBreakdown.totalLiabilities(accounts) == 2_000)
        #expect(AssetBreakdown.netTotal(accounts) == 19_000)
        #expect(AssetBreakdown.breakdown(accounts).map(\.type) == [.cash, .investment])
    }
}

// MARK: - 账号隔离与删除联动（SwiftData）

/// 测试夹具：必须用局部常量持有 `PersistenceController`。
/// 写成 `PersistenceController(inMemory: true).container.mainContext` 时容器会随临时实例被释放，
/// 随后的 `insert` / `save` 会直接触发 SwiftData 内部断言（SIGTRAP）。
@MainActor
private final class TodoAssetTestHarness {
    let controller: PersistenceController
    let context: ModelContext

    init() {
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
    }
}

@MainActor
struct TodoAssetIsolationTests {

    private func makeTodo(identifier: String, context: ModelContext) {
        let item = TodoItem(title: "写周报", priority: TodoPriority.high, createdBy: identifier, updatedBy: identifier)
        context.insert(item)
        let subtask = TodoSubtask(title: "整理数据")
        context.insert(subtask)
        subtask.owner = item
        let tag = TodoTag(name: "工作", createdBy: identifier)
        context.insert(tag)
        tag.items = [item]
    }

    private func makeMemo(identifier: String, context: ModelContext) {
        context.insert(MemoNote(content: "内容", createdBy: identifier, updatedBy: identifier))
    }

    private func makeAsset(identifier: String, context: ModelContext) {
        context.insert(AssetAccount(name: "现金", type: AssetType.cash.rawValue, balance: 1_000,
                                    createdBy: identifier, updatedBy: identifier))
        context.insert(AssetSnapshot(date: Date(), totalAssets: 1_000, totalLiabilities: 0, createdBy: identifier))
    }

    @Test
    func dataIsIsolatedByCreatedBy() throws {
        let harness = TodoAssetTestHarness()
        let context = harness.context
        UserDefaults.standard.set("user_a", forKey: "AuthUserIdentifier")
        makeTodo(identifier: "user_a", context: context)
        makeMemo(identifier: "user_a", context: context)
        makeAsset(identifier: "user_a", context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TodoItem>(predicate: PersistenceController.todoUserPredicate)).count == 1)
        #expect(try context.fetch(FetchDescriptor<MemoNote>(predicate: PersistenceController.memoUserPredicate)).count == 1)
        #expect(try context.fetch(FetchDescriptor<AssetAccount>(predicate: PersistenceController.assetAccountUserPredicate)).count == 1)

        UserDefaults.standard.set("user_b", forKey: "AuthUserIdentifier")
        #expect(try context.fetch(FetchDescriptor<TodoItem>(predicate: PersistenceController.todoUserPredicate)).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MemoNote>(predicate: PersistenceController.memoUserPredicate)).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AssetAccount>(predicate: PersistenceController.assetAccountUserPredicate)).isEmpty)
        UserDefaults.standard.removeObject(forKey: "AuthUserIdentifier")
    }

    @Test
    func deleteTodoAndAssetDataClearsOnlyTargetAccount() throws {
        let harness = TodoAssetTestHarness()
        let context = harness.context
        makeTodo(identifier: "user_a", context: context)
        makeMemo(identifier: "user_a", context: context)
        makeAsset(identifier: "user_a", context: context)
        makeMemo(identifier: "user_b", context: context)
        try context.save()

        AuthManager.deleteTodoAndAssetData(identifier: "user_a", context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TodoItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TodoSubtask>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TodoTag>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AssetAccount>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AssetSnapshot>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MemoNote>()).count == 1, "其它账号的备忘必须保留")
    }
}
