//
//  TodoLogicTests.swift
//  iFinanceTests
//
//  M1 纯逻辑回归：待办分组 / 排序、重复规则推进、备忘排序。
//

import XCTest
@testable import iFinance

final class TodoLogicTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    private func snapshot(
        title: String = "测试",
        due: Date?,
        priority: Int16 = 0,
        isDone: Bool = false,
        repeatRule: String = "none",
        createdAt: Date = Date()
    ) -> TodoSnapshot {
        TodoSnapshot(
            id: UUID(),
            title: title,
            note: nil,
            dueDate: due,
            priority: priority,
            isDone: isDone,
            repeatRule: repeatRule,
            createdAt: createdAt
        )
    }

    // MARK: - 分组（逾期 / 今天 / 未来 7 天 / 以后 / 无日期 / 已完成）

    func testGroupingBuckets() {
        let now = date(2026, 6, 15, 10)

        XCTAssertEqual(TodoGrouping.group(of: snapshot(due: date(2026, 6, 14)), now: now, calendar: calendar), .overdue)
        XCTAssertEqual(TodoGrouping.group(of: snapshot(due: date(2026, 6, 15, 23)), now: now, calendar: calendar), .today)
        XCTAssertEqual(TodoGrouping.group(of: snapshot(due: date(2026, 6, 22, 23)), now: now, calendar: calendar), .nextSevenDays)
        XCTAssertEqual(TodoGrouping.group(of: snapshot(due: date(2026, 6, 23)), now: now, calendar: calendar), .later)
        XCTAssertEqual(TodoGrouping.group(of: snapshot(due: nil), now: now, calendar: calendar), .noDate)
        XCTAssertEqual(TodoGrouping.group(of: snapshot(due: date(2026, 6, 14), isDone: true), now: now, calendar: calendar), .completed,
                       "已完成优先于逾期")
    }

    func testGroupedKeepsFixedOrderAndSkipsEmptyGroups() {
        let now = date(2026, 6, 15, 10)
        let items = [
            snapshot(title: "以后", due: date(2026, 7, 1)),
            snapshot(title: "今天", due: date(2026, 6, 15)),
            snapshot(title: "逾期", due: date(2026, 6, 1))
        ]
        let groups = TodoGrouping.grouped(items, now: now, calendar: calendar)
        XCTAssertEqual(groups.map(\.group), [.overdue, .today, .later], "按固定顺序返回且跳过空分组")
        XCTAssertEqual(groups.first?.items.first?.title, "逾期")
    }

    func testSortPrefersHigherPriorityThenEarlierDueDate() {
        let items = [
            snapshot(title: "低-今天", due: date(2026, 6, 15), priority: TodoPriority.low),
            snapshot(title: "高-明天", due: date(2026, 6, 16), priority: TodoPriority.high),
            snapshot(title: "中-今天", due: date(2026, 6, 15), priority: TodoPriority.medium)
        ]
        let sorted = TodoGrouping.sorted(items, in: .today, calendar: calendar)
        XCTAssertEqual(sorted.map(\.title), ["高-明天", "中-今天", "低-今天"], "优先级权重优先，其次截止日")

        let mixedDueDates = [
            snapshot(title: "无日期", due: nil),
            snapshot(title: "有日期", due: date(2026, 7, 1))
        ]
        XCTAssertEqual(TodoGrouping.sorted(mixedDueDates, in: .later, calendar: calendar).first?.title, "有日期",
                       "无截止日排在同组末尾")
    }

    func testCompletedGroupSortsByCreatedAtDescending() {
        let older = snapshot(title: "旧", due: nil, isDone: true, createdAt: date(2026, 6, 1))
        let newer = snapshot(title: "新", due: nil, isDone: true, createdAt: date(2026, 6, 10))
        let sorted = TodoGrouping.sorted([older, newer], in: .completed, calendar: calendar)
        XCTAssertEqual(sorted.map(\.title), ["新", "旧"])
    }

    // MARK: - 重复规则（含月末 / 闰年）

    func testRepeatRulesAdvanceOnePeriod() {
        let base = date(2026, 6, 15)
        XCTAssertEqual(TodoRepeat.nextDueDate(after: base, rule: TodoRepeat.daily, calendar: calendar), date(2026, 6, 16))
        XCTAssertEqual(TodoRepeat.nextDueDate(after: base, rule: TodoRepeat.weekly, calendar: calendar), date(2026, 6, 22))
        XCTAssertEqual(TodoRepeat.nextDueDate(after: base, rule: TodoRepeat.monthly, calendar: calendar), date(2026, 7, 15))
        XCTAssertEqual(TodoRepeat.nextDueDate(after: base, rule: TodoRepeat.yearly, calendar: calendar), date(2027, 6, 15))
        XCTAssertNil(TodoRepeat.nextDueDate(after: base, rule: TodoRepeat.noneRule, calendar: calendar))
    }

    func testMonthlyRepeatClampsMonthEnd() {
        let jan31 = date(2026, 1, 31)
        let next = TodoRepeat.nextDueDate(after: jan31, rule: TodoRepeat.monthly, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: next ?? jan31), 2)
        XCTAssertEqual(calendar.component(.day, from: next ?? jan31), 28, "2026 年 2 月只有 28 天")
    }

    func testMonthlyRepeatHandlesLeapYear() {
        let jan31 = date(2028, 1, 31)
        let next = TodoRepeat.nextDueDate(after: jan31, rule: TodoRepeat.monthly, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: next ?? jan31), 2)
        XCTAssertEqual(calendar.component(.day, from: next ?? jan31), 29, "2028 年是闰年")
    }

    // MARK: - 优先级

    func testPrioritySortWeightAndLocalizationKeys() {
        XCTAssertLessThan(TodoPriority.sortWeight(TodoPriority.high), TodoPriority.sortWeight(TodoPriority.none))
        XCTAssertEqual(TodoPriority.localizedKey(TodoPriority.high), "todo.priority.high")
        XCTAssertEqual(TodoPriority.localizedKey(99), "todo.priority.none", "未知优先级回落为「无」")
    }

    // MARK: - 备忘排序

    func testMemoSortingPinsFirstThenUpdatedAt() {
        let a = UUID(), b = UUID(), c = UUID()
        let sorted = MemoSorting.sorted([
            (id: a, isPinned: false, updatedAt: date(2026, 6, 10)),
            (id: b, isPinned: true, updatedAt: date(2026, 6, 1)),
            (id: c, isPinned: false, updatedAt: date(2026, 6, 20))
        ])
        XCTAssertEqual(sorted, [b, c, a], "置顶优先，其余按更新时间倒序")
    }
}
