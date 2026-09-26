//
//  TodoEditRulesTests.swift
//  iFinanceTests
//
//  M2 纯逻辑回归：标签名校验 / 数量上限、重复待办「下一期」推进。
//

import XCTest
@testable import iFinance

final class TodoTagRulesTests: XCTestCase {

    // MARK: - 名称校验

    func testValidateRejectsEmptyName() {
        XCTAssertEqual(TodoTagRules.validate("", existingNames: []), .empty)
        XCTAssertEqual(TodoTagRules.validate("   ", existingNames: []), .empty)
    }

    func testValidateAcceptsNameWithinLengthLimit() {
        XCTAssertEqual(TodoTagRules.validate("工作", existingNames: []), .valid)
        XCTAssertEqual(TodoTagRules.validate("12345678", existingNames: ["其他"]), .valid, "8 个字符是上限内的边界值")
        XCTAssertEqual(TodoTagRules.validate("  学习  ", existingNames: []), .valid, "首尾空白先裁剪")
    }

    func testValidateRejectsTooLongName() {
        XCTAssertEqual(TodoTagRules.validate("123456789", existingNames: []), .tooLong, "9 个字符超限")
    }

    func testValidateRejectsDuplicateIgnoringCase() {
        XCTAssertEqual(TodoTagRules.validate("工作", existingNames: ["工作"]), .duplicate)
        XCTAssertEqual(TodoTagRules.validate("work", existingNames: ["Work"]), .duplicate, "重名判断忽略大小写")
    }

    // MARK: - 数量上限

    func testCanAddRespectsLimit() {
        XCTAssertTrue(TodoTagRules.canAdd(existingCount: TodoTagRules.maxCount - 1))
        XCTAssertFalse(TodoTagRules.canAdd(existingCount: TodoTagRules.maxCount))
    }
}

final class TodoRecurrenceTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    private func snapshot(
        due: Date?,
        priority: Int16 = TodoPriority.medium,
        repeatRule: String
    ) -> TodoSnapshot {
        TodoSnapshot(
            id: UUID(),
            title: "交月报",
            note: "记得附数据",
            dueDate: due,
            priority: priority,
            isDone: false,
            repeatRule: repeatRule,
            createdAt: date(2026, 6, 1)
        )
    }

    func testNextDraftAdvancesMonthlyDueDate() {
        let now = date(2026, 6, 15, 12)
        let draft = TodoRecurrence.nextDraft(
            after: snapshot(due: date(2026, 6, 15), repeatRule: TodoRepeat.monthly),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(draft?.dueDate, date(2026, 7, 15), "月重复推进一个月")
        XCTAssertEqual(draft?.title, "交月报", "标题沿用")
        XCTAssertEqual(draft?.note, "记得附数据", "备注沿用")
        XCTAssertEqual(draft?.priority, TodoPriority.medium, "优先级沿用")
        XCTAssertEqual(draft?.repeatRule, TodoRepeat.monthly, "重复规则沿用")
        XCTAssertEqual(draft?.isDone, false, "下一期默认未完成")
        XCTAssertEqual(draft?.createdAt, now, "创建时间取生成时刻")
        XCTAssertNotNil(draft?.id)
    }

    func testNextDraftClampsMonthEndByCalendar() {
        // 1 月 31 日 + 1 个月 = 2 月 28/29 日（由 Calendar 收敛）
        let draft = TodoRecurrence.nextDraft(
            after: snapshot(due: date(2026, 1, 31), repeatRule: TodoRepeat.monthly),
            calendar: calendar
        )
        XCTAssertEqual(draft?.dueDate, date(2026, 2, 28))
    }

    func testNextDraftReturnsNilWhenNotRepeatingOrWithoutDueDate() {
        XCTAssertNil(
            TodoRecurrence.nextDraft(
                after: snapshot(due: date(2026, 6, 15), repeatRule: TodoRepeat.noneRule),
                calendar: calendar
            ),
            "不重复的待办不生成下一期"
        )
        XCTAssertNil(
            TodoRecurrence.nextDraft(
                after: snapshot(due: nil, repeatRule: TodoRepeat.daily),
                calendar: calendar
            ),
            "没有截止日无法推进"
        )
    }
}
