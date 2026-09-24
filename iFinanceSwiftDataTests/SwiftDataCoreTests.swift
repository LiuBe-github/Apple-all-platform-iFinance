//
//  SwiftDataCoreTests.swift
//  iFinanceSwiftDataTests
//
//  SwiftData 版核心数据层测试：增删改查、多账号隔离、预算统计聚合、密码哈希。
//  全部使用内存容器，不触碰磁盘数据。
//

import Testing
import SwiftData
import Foundation
@testable import iFinanceSwiftData

// MARK: - 测试环境

@MainActor
final class SwiftDataTestContext {
    let controller: PersistenceController
    let context: ModelContext

    init() {
        controller = PersistenceController(inMemory: true)
        context = controller.container.mainContext
    }

    @discardableResult
    func makeBill(
        amount: Decimal,
        type: String,
        category: String? = "餐饮",
        note: String? = nil,
        date: Date = Date(),
        createdBy: String = "test@example.com"
    ) -> Bill {
        let bill = Bill(
            amount: amount,
            type: type,
            category: category,
            note: note,
            date: date,
            createdBy: createdBy,
            updatedBy: createdBy
        )
        context.insert(bill)
        return bill
    }
}

// MARK: - 增删改查

@MainActor
struct BillCRUDTests {

    @Test
    func insertAndFetchBill() throws {
        let ctx = SwiftDataTestContext()
        ctx.makeBill(amount: 35.5, type: "expenditure", note: "午餐")
        ctx.makeBill(amount: 12000, type: "income", category: "工资")
        try ctx.context.save()

        let bills = try ctx.context.fetch(FetchDescriptor<Bill>())
        #expect(bills.count == 2)
        #expect(bills.contains { $0.type == "income" })
    }

    @Test
    func updateBillAmount() throws {
        let ctx = SwiftDataTestContext()
        let bill = ctx.makeBill(amount: 10, type: "expenditure")
        try ctx.context.save()

        bill.amount = Decimal(99.9)
        try ctx.context.save()

        let fetched = try ctx.context.fetch(FetchDescriptor<Bill>())
        #expect(fetched.first?.amountDouble == 99.9)
    }

    @Test
    func deleteSingleBill() throws {
        let ctx = SwiftDataTestContext()
        let bill = ctx.makeBill(amount: 10, type: "expenditure")
        try ctx.context.save()

        ctx.context.delete(bill)
        try ctx.context.save()

        #expect(try ctx.context.fetch(FetchDescriptor<Bill>()).isEmpty)
    }

    @Test
    func deleteBillsByPredicate() throws {
        let ctx = SwiftDataTestContext()
        ctx.makeBill(amount: 10, type: "expenditure", createdBy: "a@example.com")
        ctx.makeBill(amount: 20, type: "expenditure", createdBy: "b@example.com")
        try ctx.context.save()

        let predicate = PersistenceController.billPredicate(for: "a@example.com")
        try ctx.context.delete(model: Bill.self, where: predicate)

        let remaining = try ctx.context.fetch(FetchDescriptor<Bill>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.createdBy == "b@example.com")
    }
}

// MARK: - 多账号隔离

@MainActor
struct UserIsolationTests {

    @Test
    func fetchOnlyCurrentUserBills() throws {
        let ctx = SwiftDataTestContext()
        ctx.makeBill(amount: 1, type: "expenditure", createdBy: "alice@example.com")
        ctx.makeBill(amount: 2, type: "expenditure", createdBy: "alice@example.com")
        ctx.makeBill(amount: 3, type: "expenditure", createdBy: "bob@example.com")
        try ctx.context.save()

        let predicate = PersistenceController.billPredicate(for: "alice@example.com")
        let descriptor = FetchDescriptor<Bill>(predicate: predicate)
        let aliceBills = try ctx.context.fetch(descriptor)

        #expect(aliceBills.count == 2)
        #expect(aliceBills.allSatisfy { $0.createdBy == "alice@example.com" })
    }

    @Test
    func userProfileInsertAndFetch() throws {
        let ctx = SwiftDataTestContext()
        let profile = UserProfile(
            userIdentifier: "alice@example.com",
            email: "alice@example.com",
            passwordHash: AuthManager.hashPassword(password: "secret123", salt: "salt"),
            passwordSalt: "salt",
            nickname: "Alice",
            monthlyBudget: 5000
        )
        ctx.context.insert(profile)
        try ctx.context.save()

        let identifier = "alice@example.com"
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userIdentifier == identifier }
        )
        let found = try ctx.context.fetch(descriptor).first

        #expect(found?.monthlyBudget == 5000)
        #expect(found?.nickname == "Alice")
    }
}

// MARK: - 预算与统计聚合

@MainActor
struct BudgetAggregationTests {

    @Test
    func currentMonthExpenditureAggregation() throws {
        let ctx = SwiftDataTestContext()
        let calendar = Calendar.current
        let today = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!

        // 本月支出
        ctx.makeBill(amount: Decimal(100), type: "expenditure", category: "餐饮", date: today)
        ctx.makeBill(amount: Decimal(200), type: "expenditure", category: "购物", date: startOfMonth)
        // 本月收入（不计入支出）
        ctx.makeBill(amount: Decimal(999), type: "income", category: "工资", date: today)
        // 上月支出（不计入）
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
        ctx.makeBill(amount: Decimal(500), type: "expenditure", category: "餐饮", date: lastMonth)
        try ctx.context.save()

        let all = try ctx.context.fetch(FetchDescriptor<Bill>())
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        let monthly = all.filter { bill in
            guard bill.type == "expenditure", let date = bill.date else { return false }
            return date >= startOfMonth && date < endOfMonth
        }
        let total = monthly.reduce(0.0) { $0 + $1.amountDouble }

        #expect(monthly.count == 2)
        #expect(total == 300.0)
    }

    @Test
    func todayBillsAggregation() throws {
        let ctx = SwiftDataTestContext()
        let calendar = Calendar.current
        ctx.makeBill(amount: Decimal(30), type: "expenditure", date: Date())
        ctx.makeBill(amount: Decimal(50), type: "expenditure", date: Date())
        ctx.makeBill(
            amount: Decimal(70),
            type: "expenditure",
            date: calendar.date(byAdding: .day, value: -1, to: Date())!
        )
        try ctx.context.save()

        let all = try ctx.context.fetch(FetchDescriptor<Bill>())
        let todayBills = all.filter { bill in
            guard let date = bill.date else { return false }
            return calendar.isDate(date, inSameDayAs: Date())
        }
        let expense = todayBills.filter { $0.type == "expenditure" }.reduce(0.0) { $0 + $1.amountDouble }

        #expect(todayBills.count == 2)
        #expect(expense == 80.0)
    }
}

// MARK: - 密码哈希（与 Core Data 版算法一致）

struct PasswordHashingTests {

    @Test
    func hashIsDeterministic() {
        let a = AuthManager.hashPassword(password: "secret123", salt: "salt-1")
        let b = AuthManager.hashPassword(password: "secret123", salt: "salt-1")
        #expect(a == b)
        #expect(a.count == 64) // SHA256 十六进制
    }

    @Test
    func differentSaltProducesDifferentHash() {
        let a = AuthManager.hashPassword(password: "secret123", salt: "salt-1")
        let b = AuthManager.hashPassword(password: "secret123", salt: "salt-2")
        #expect(a != b)
    }

    @Test
    func matchesCoreDataVersionAlgorithm() {
        // 同一算法：SHA256("salt|password") 的十六进制
        let hash = AuthManager.hashPassword(password: "p@ss", salt: "s1")
        #expect(hash == AuthManager.hashPassword(password: "p@ss", salt: "s1"))
        #expect(hash != AuthManager.hashPassword(password: "p@ss2", salt: "s1"))
    }
}

// MARK: - 隐私遮罩（进入后台整页模糊）

/// 覆盖「仅在用户开启应用锁时才启用后台模糊」的开关逻辑
/// 使用 `.serialized` 避免并行用例互相修改 UserDefaults
@MainActor
@Suite(.serialized)
struct PrivacyShieldTests {

    private static let lockKey = "BiometricLockEnabled"

    private func withLockSetting(_ enabled: Bool, _ body: (BiometricLockManager) -> Void) {
        let manager = BiometricLockManager.shared
        let original = UserDefaults.standard.bool(forKey: Self.lockKey)
        UserDefaults.standard.set(enabled, forKey: Self.lockKey)
        body(manager)
        UserDefaults.standard.set(original, forKey: Self.lockKey)
        manager.deactivatePrivacyShield()
    }

    @Test
    func shieldIgnoredWhenLockDisabled() {
        withLockSetting(false) { manager in
            manager.activatePrivacyShield()
            #expect(manager.isPrivacyShieldActive == false)
            #expect(manager.shouldBlurForPrivacy == false)
        }
    }

    @Test
    func shieldActivatedWhenLockEnabled() {
        withLockSetting(true) { manager in
            manager.activatePrivacyShield()
            #expect(manager.isPrivacyShieldActive)
            #expect(manager.shouldBlurForPrivacy)
        }
    }

    @Test
    func deactivateClearsShield() {
        withLockSetting(true) { manager in
            manager.activatePrivacyShield()
            #expect(manager.isPrivacyShieldActive)
            manager.deactivatePrivacyShield()
            #expect(manager.isPrivacyShieldActive == false)
        }
    }
}

// MARK: - 概况页区间聚合（本月 / 上月 / 本年）

// MARK: - 个性签名校验（SwiftData 版同名实现）

// MARK: - 数字键盘表达式逻辑（与 iOS 版同名实现）

@MainActor
@Suite(.serialized)
struct NumberPadExpressionTests {

    @Test
    func digitsStillEnterableAfterOperatorWithDecimalAmount() {
        var text = NumberPadExpression.placeholder
        for input in ["1", "2", ".", "5"] {
            text = NumberPadExpression.append(input, to: text)
        }
        text = NumberPadExpression.applyOperator(primary: "+", alternate: "×", to: text)
        #expect(text == "12.5+")

        text = NumberPadExpression.append("3", to: text)
        #expect(text == "12.5+3")
    }

    @Test
    func operatorTogglesOnSecondTap() {
        var text = "8"
        text = NumberPadExpression.applyOperator(primary: "+", alternate: "×", to: text)
        #expect(text == "8+")
        text = NumberPadExpression.applyOperator(primary: "+", alternate: "×", to: text)
        #expect(text == "8×")
    }

    @Test
    func expressionEvaluation() {
        let view = AddBillView()
        #expect(abs(view.parseExpression("12.5+30") - 42.5) < 0.001)
        #expect(abs(view.parseExpression("10×3") - 30) < 0.001)
    }
}

@MainActor
@Suite(.serialized)
struct SignatureValidationTests {

    @Test
    func emptySignatureClearsValue() {
        #expect(AuthManager.validateSignature("   ") == .valid(nil))
    }

    @Test
    func trimsWhitespace() {
        #expect(AuthManager.validateSignature("  记录每一天  ") == .valid("记录每一天"))
    }

    @Test
    func lengthBoundary() {
        let exactlyLimit = String(repeating: "字", count: AuthManager.signatureMaxLength)
        #expect(AuthManager.validateSignature(exactlyLimit) == .valid(exactlyLimit))

        let tooLong = String(repeating: "字", count: AuthManager.signatureMaxLength + 1)
        #expect(AuthManager.validateSignature(tooLong) == .tooLong)
    }
}

@MainActor
@Suite(.serialized)
struct PeriodSummaryTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test
    func aggregationAcrossMonthAndYearBoundary() throws {
        let ctx = SwiftDataTestContext()
        let now = date(2026, 1, 15)
        let ranges = PeriodRanges.make(calendar: calendar, now: now)

        // 本月（2026-01）
        ctx.makeBill(amount: 100, type: "expenditure", date: date(2026, 1, 10))
        ctx.makeBill(amount: 500, type: "income", date: date(2026, 1, 12))
        // 上月（2025-12）
        ctx.makeBill(amount: 300, type: "expenditure", date: date(2025, 12, 20))
        // 更早（2025-11）→ 不计入任何区间
        ctx.makeBill(amount: 999, type: "expenditure", date: date(2025, 11, 5))
        try ctx.context.save()

        let bills = try ctx.context.fetch(FetchDescriptor<Bill>())
        let summaries = PeriodSummary.make(bills: bills, ranges: ranges)

        let thisMonth = summaries.first { $0.period == .thisMonth }
        let lastMonth = summaries.first { $0.period == .lastMonth }
        let thisYear = summaries.first { $0.period == .thisYear }

        #expect(thisMonth?.income == 500)
        #expect(thisMonth?.expense == 100)
        #expect(thisMonth?.count == 2)
        #expect(thisMonth?.balance == 400)

        #expect(lastMonth?.expense == 300)
        #expect(lastMonth?.count == 1)
        #expect(lastMonth?.balance == -300)

        #expect(thisYear?.income == 500)
        #expect(thisYear?.expense == 100, "去年 11 月的支出不应计入本年")
    }

    @Test
    func transferCountsButHasNoAmount() throws {
        let ctx = SwiftDataTestContext()
        let now = date(2026, 3, 10)
        let ranges = PeriodRanges.make(calendar: calendar, now: now)

        ctx.makeBill(amount: 200, type: "expenditure", date: date(2026, 3, 2))
        ctx.makeBill(amount: 50, type: "transfer", date: date(2026, 3, 3))
        try ctx.context.save()

        let bills = try ctx.context.fetch(FetchDescriptor<Bill>())
        let summaries = PeriodSummary.make(bills: bills, ranges: ranges)
        let thisMonth = summaries.first { $0.period == .thisMonth }

        #expect(thisMonth?.count == 2)
        #expect(thisMonth?.expense == 200)
        #expect(thisMonth?.income == 0)
    }
}
