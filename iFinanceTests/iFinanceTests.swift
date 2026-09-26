//
//  iFinanceTests.swift
//  iFinanceTests
//

import XCTest
@testable import iFinance
import CoreData
import CryptoKit
import SwiftUI
import Charts

@MainActor
final class iFinanceTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    // MARK: - 测试前准备（每个测试用例执行前调用）
    override func setUpWithError() throws {
        try super.setUpWithError()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        persistenceController = nil
        try super.tearDownWithError()
    }

    // MARK: - PersistenceController 测试

    func testPersistenceControllerSharedExists() {
        XCTAssertNotNil(PersistenceController.shared)
        XCTAssertNotNil(PersistenceController.shared.container)
    }

    func testPersistenceControllerInMemory() {
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.container)

        let bill = Bill(context: controller.container.viewContext)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(string: "99.9")
        bill.date = Date()
        bill.type = "expenditure"
        bill.category = "测试"
        bill.createdBy = "test@example.com"
        bill.createdAt = Date()
        bill.updatedAt = Date()

        XCTAssertNoThrow(try controller.container.viewContext.save())
    }

    func testPersistenceControllerBillUserPredicate() {
        let predicate = PersistenceController.billUserPredicate
        XCTAssertNotNil(predicate)
    }

    func testPersistenceControllerCurrentUserIdentifier() {
        let identifier = PersistenceController.currentUserIdentifier
        XCTAssertFalse(identifier.isEmpty)
    }

    // MARK: - Bill 模型测试

    func testBillCreation() {
        let bill = Bill(context: context)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(string: "123.45")
        bill.date = Date()
        bill.type = "expenditure"
        bill.category = "餐饮"
        bill.note = "午餐"
        bill.createdBy = "test@example.com"
        bill.createdAt = Date()
        bill.updatedAt = Date()

        XCTAssertNoThrow(try context.save())

        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        let results = try? context.fetch(request)
        XCTAssertNotNil(results)
        XCTAssertEqual(results?.count, 1)
        XCTAssertEqual(results?.first?.amount?.doubleValue, 123.45)
        XCTAssertEqual(results?.first?.type, "expenditure")
    }

    func testBillAmountDecimalValue() {
        let bill = Bill(context: context)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(string: "88.88")
        bill.date = Date()
        bill.type = "income"
        bill.createdBy = "test@example.com"
        bill.createdAt = Date()

        let decimalValue = bill.amount?.decimalValue ?? Decimal(0)
        XCTAssertEqual(decimalValue, Decimal(string: "88.88"))
    }

    func testBillDateGrouping() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let bill1 = Bill(context: context)
        bill1.id = UUID()
        bill1.amount = NSDecimalNumber(string: "10")
        bill1.date = today
        bill1.type = "expenditure"
        bill1.createdBy = "test@example.com"
        bill1.createdAt = Date()

        let bill2 = Bill(context: context)
        bill2.id = UUID()
        bill2.amount = NSDecimalNumber(string: "20")
        bill2.date = yesterday
        bill2.type = "expenditure"
        bill2.createdBy = "test@example.com"
        bill2.createdAt = Date()

        try? context.save()

        let todayStart = calendar.startOfDay(for: today)
        let yesterdayStart = calendar.startOfDay(for: yesterday)

        XCTAssertEqual(calendar.startOfDay(for: bill1.date ?? Date()), todayStart)
        XCTAssertEqual(calendar.startOfDay(for: bill2.date ?? Date()), yesterdayStart)
    }

    func testBillDelete() {
        // 创建并保存账单
        let bill = Bill(context: context)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(string: "50")
        bill.date = Date()
        bill.type = "expenditure"
        bill.category = "餐饮"
        bill.createdBy = "test@example.com"
        bill.createdAt = Date()
        try? context.save()

        // 确认账单已存在
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        let resultsBefore = try? context.fetch(request)
        XCTAssertEqual(resultsBefore?.count, 1, "删除前应有 1 条账单")

        // 删除账单
        context.delete(bill)
        try? context.save()

        // 确认账单已删除
        let resultsAfter = try? context.fetch(request)
        XCTAssertEqual(resultsAfter?.count, 0, "删除后账单数量应为 0")
    }

    func testBillDeleteAndVerifyDayNetRecalculation() {
        // 场景：删除一笔支出后，当日结余应重新计算
        let calendar = Calendar.current
        let today = Date()

        let bill1 = Bill(context: context)
        bill1.id = UUID()
        bill1.amount = NSDecimalNumber(string: "40")
        bill1.date = today
        bill1.type = "expenditure"
        bill1.createdBy = "test@example.com"
        bill1.createdAt = Date()

        let bill2 = Bill(context: context)
        bill2.id = UUID()
        bill2.amount = NSDecimalNumber(string: "100")
        bill2.date = today
        bill2.type = "income"
        bill2.createdBy = "test@example.com"
        bill2.createdAt = Date()

        try? context.save()

        // 删除支出账单前：dayNet = 100 - 40 = 60
        let billsBefore = (try? context.fetch(Bill.fetchRequest())) ?? []
        let dayNetBefore = billsBefore.reduce(0.0) { total, b in
            let amt = b.amount?.doubleValue ?? 0
            return b.type == "expenditure" ? total - amt : total + amt
        }
        XCTAssertEqual(dayNetBefore, 60.0, accuracy: 0.001)

        // 删除支出账单
        context.delete(bill1)
        try? context.save()

        // 删除支出账单后：dayNet = 100（只剩收入）
        let billsAfter = (try? context.fetch(Bill.fetchRequest())) ?? []
        let dayNetAfter = billsAfter.reduce(0.0) { total, b in
            let amt = b.amount?.doubleValue ?? 0
            return b.type == "expenditure" ? total - amt : total + amt
        }
        XCTAssertEqual(dayNetAfter, 100.0, accuracy: 0.001, "删除支出后 dayNet 应重新计算")
    }

    // MARK: - AuthManager 测试（static 方法）

    func testHashPasswordConsistent() {
        let password = "Test123456"
        let salt = "test-salt-123"
        let hash1 = AuthManager.hashPassword(password: password, salt: salt)
        let hash2 = AuthManager.hashPassword(password: password, salt: salt)
        XCTAssertEqual(hash1, hash2, "相同密码+salt应产生相同哈希")
    }

    func testHashPasswordDifferentSalt() {
        let password = "Test123456"
        let hash1 = AuthManager.hashPassword(password: password, salt: "salt-A")
        let hash2 = AuthManager.hashPassword(password: password, salt: "salt-B")
        XCTAssertNotEqual(hash1, hash2, "不同salt应产生不同哈希")
    }

    func testHashPasswordDifferentPassword() {
        let salt = "same-salt"
        let hash1 = AuthManager.hashPassword(password: "Password1", salt: salt)
        let hash2 = AuthManager.hashPassword(password: "Password2", salt: salt)
        XCTAssertNotEqual(hash1, hash2, "不同密码应产生不同哈希")
    }

    func testHashPasswordOutputFormat() {
        let hash = AuthManager.hashPassword(password: "any", salt: "salt")
        // SHA256 输出应为 64 个十六进制字符
        XCTAssertEqual(hash.count, 64)
        let hexCharacters = "0123456789abcdef"
        XCTAssertTrue(hash.allSatisfy { hexCharacters.contains($0) })
    }

    // MARK: - AuthManager 注册与登录流程测试

    func testRegisterPasswordTooShort() {
        let email = "short_\(UUID().uuidString.prefix(8))@example.com"
        let result = AuthManager.shared.register(
            email: email, phone: "", password: "123", confirmPassword: "123", fieldType: .email)
        XCTAssertNotNil(result, "密码少于6位应返回错误key")
        XCTAssertEqual(result, "auth.password_too_short")
    }

    func testRegisterPasswordNotMatch() {
        let email = "mismatch_\(UUID().uuidString.prefix(8))@example.com"
        let result = AuthManager.shared.register(
            email: email, phone: "", password: "123456", confirmPassword: "654321", fieldType: .email)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, "auth.password_not_match")
    }

    func testLoginWrongPassword() {
        let email = "login_\(UUID().uuidString.prefix(8))@example.com"
        _ = AuthManager.shared.register(
            email: email, phone: "", password: "123456", confirmPassword: "123456", fieldType: .email)

        let result = AuthManager.shared.login(
            email: email, phone: "", password: "wrongpassword", fieldType: .email)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, "auth.invalid_credentials")
    }

    // MARK: - AuthManager 第三方登录防护

    func testLoginWithProviderRejectsWeChatAndQQ() {
        XCTAssertEqual(AuthManager.shared.loginWithProvider(.wechat, identifier: "wx_test"), "auth.coming_soon")
        XCTAssertEqual(AuthManager.shared.loginWithProvider(.qq, identifier: "qq_test"), "auth.coming_soon")
    }

    // MARK: - 支出分类测试

    func testExpenditureCategoryAllCases() {
        let all = ExpenditureCategory.allCases
        // 枚举中共有 25 个 case
        XCTAssertEqual(all.count, 25)
    }

    func testExpenditureCategoryRawValues() {
        XCTAssertEqual(ExpenditureCategory.foodAndBeverage.rawValue, "餐饮")
        XCTAssertEqual(ExpenditureCategory.shopping.rawValue, "购物")
        XCTAssertEqual(ExpenditureCategory.digital.rawValue, "数码")
    }

    func testExpenditureCategoryIcons() {
        XCTAssertEqual(ExpenditureCategory.foodAndBeverage.icon, "fork.knife")
        XCTAssertEqual(ExpenditureCategory.shopping.icon, "cart")
        // 图标体系重排后：数码 / 通讯不再共用 phone，交通 / 汽车不再共用 car
        XCTAssertEqual(ExpenditureCategory.digital.icon, "laptopcomputer.and.iphone")
        XCTAssertEqual(ExpenditureCategory.communication.icon, "antenna.radiowaves.left.and.right")
        XCTAssertEqual(ExpenditureCategory.traffic.icon, "road.lanes")
        XCTAssertEqual(ExpenditureCategory.car.icon, "car.side")
        XCTAssertEqual(ExpenditureCategory.medical.icon, "cross.case")
    }

    func testExpenditureCategoryLocalizedDisplayName() {
        let cat = ExpenditureCategory.foodAndBeverage
        let name = cat.localizedDisplayName
        XCTAssertFalse(name.isEmpty, "localizedDisplayName 不应为空")
    }

    // MARK: - 收入分类测试

    func testIncomeCategoryAllCases() {
        let all = IncomeCategory.allCases
        // 枚举中共有 12 个 case（新增「生活费」）
        XCTAssertEqual(all.count, 12)
    }

    func testIncomeCategoryRawValues() {
        XCTAssertEqual(IncomeCategory.salary.rawValue, "工资")
        XCTAssertEqual(IncomeCategory.bonus.rawValue, "奖金")
        XCTAssertEqual(IncomeCategory.unexpectedIncom.rawValue, "意外收入")
    }

    func testIncomeCategoryIcons() {
        XCTAssertEqual(IncomeCategory.salary.icon, "wallet.bifold")
        XCTAssertEqual(IncomeCategory.bonus.icon, "dollarsign.circle")
        XCTAssertEqual(IncomeCategory.unexpectedIncom.icon, "exclamationmark.bubble")
        XCTAssertEqual(IncomeCategory.livingAllowance.icon, "banknote")
    }

    // MARK: - TimeRange 日期范围测试

    func testTimeRangeToday() {
        let range = TimeRange.today.dateRange
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        XCTAssertEqual(range.start, startOfDay)
        XCTAssert(range.end > range.start)
    }

    func testTimeRangeThisWeek() {
        let range = TimeRange.thisWeek.dateRange
        XCTAssert(range.end > range.start)
        let days = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        XCTAssertLessThanOrEqual(days, 7)
    }

    func testTimeRangeThisMonth() {
        let range = TimeRange.thisMonth.dateRange
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        XCTAssertEqual(range.start, monthStart)
    }

    func testTimeRangeThisYear() {
        let range = TimeRange.thisYear.dateRange
        let calendar = Calendar.current
        let yearStart = calendar.dateInterval(of: .year, for: Date())?.start ?? Date()
        XCTAssertEqual(range.start, yearStart)
    }

    func testTimeRangeAllCases() {
        XCTAssertEqual(TimeRange.allCases.count, 4)
    }

    // MARK: - DayGroupCard 业务逻辑测试（dayNet 计算）

    func testDayNetExpenditureOnly() {
        let bill1 = Bill(context: context)
        bill1.id = UUID()
        bill1.amount = NSDecimalNumber(string: "35")
        bill1.type = "expenditure"
        bill1.date = Date()
        bill1.createdBy = "test@example.com"
        bill1.createdAt = Date()

        let bill2 = Bill(context: context)
        bill2.id = UUID()
        bill2.amount = NSDecimalNumber(string: "15")
        bill2.type = "expenditure"
        bill2.date = Date()
        bill2.createdBy = "test@example.com"
        bill2.createdAt = Date()

        let bills = [bill1, bill2]
        let dayNet = bills.reduce(0.0) { total, bill in
            let amt = bill.amount?.doubleValue ?? 0
            return bill.type == "expenditure" ? total - amt : total + amt
        }
        XCTAssertEqual(dayNet, -50.0, accuracy: 0.001)
    }

    func testDayNetIncomeOnly() {
        let bill1 = Bill(context: context)
        bill1.id = UUID()
        bill1.amount = NSDecimalNumber(string: "100")
        bill1.type = "income"
        bill1.date = Date()
        bill1.createdBy = "test@example.com"
        bill1.createdAt = Date()

        let bill2 = Bill(context: context)
        bill2.id = UUID()
        bill2.amount = NSDecimalNumber(string: "50")
        bill2.type = "income"
        bill2.date = Date()
        bill2.createdBy = "test@example.com"
        bill2.createdAt = Date()

        let bills = [bill1, bill2]
        let dayNet = bills.reduce(0.0) { total, bill in
            let amt = bill.amount?.doubleValue ?? 0
            return bill.type == "expenditure" ? total - amt : total + amt
        }
        XCTAssertEqual(dayNet, 150.0, accuracy: 0.001)
    }

    func testDayNetMixed() {
        let bill1 = Bill(context: context)
        bill1.id = UUID()
        bill1.amount = NSDecimalNumber(string: "40")
        bill1.type = "expenditure"
        bill1.date = Date()
        bill1.createdBy = "test@example.com"
        bill1.createdAt = Date()

        let bill2 = Bill(context: context)
        bill2.id = UUID()
        bill2.amount = NSDecimalNumber(string: "100")
        bill2.type = "income"
        bill2.date = Date()
        bill2.createdBy = "test@example.com"
        bill2.createdAt = Date()

        let bills = [bill1, bill2]
        let dayNet = bills.reduce(0.0) { total, bill in
            let amt = bill.amount?.doubleValue ?? 0
            return bill.type == "expenditure" ? total - amt : total + amt
        }
        // 100 - 40 = 60
        XCTAssertEqual(dayNet, 60.0, accuracy: 0.001)
    }

    // MARK: - 编辑账单后 dayNet 重新计算（复现用户 bug）

    func testDayNetRecalculatesAfterEdit() {
        let bill = Bill(context: context)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(string: "40")
        bill.type = "expenditure"
        bill.date = Date()
        bill.category = "餐饮"
        bill.createdBy = "test@example.com"
        bill.createdAt = Date()
        bill.updatedAt = Date()

        var bills = [bill]
        var dayNet = bills.reduce(0.0) { total, b in
            let amt = b.amount?.doubleValue ?? 0
            return b.type == "expenditure" ? total - amt : total + amt
        }
        XCTAssertEqual(dayNet, -40.0, accuracy: 0.001, "初始应为 -40")

        // 模拟编辑：金额从 40 改为 35
        bill.amount = NSDecimalNumber(string: "35")
        // 重新计算 dayNet（模拟 DayGroupCard 重新渲染）
        dayNet = bills.reduce(0.0) { total, b in
            let amt = b.amount?.doubleValue ?? 0
            return b.type == "expenditure" ? total - amt : total + amt
        }
        XCTAssertEqual(dayNet, -35.0, accuracy: 0.001, "编辑后应更新为 -35")
    }

    // MARK: - 趋势页绘图测试

    /// 模拟 TendencyView 的数据聚合逻辑：将 Bills 按日期聚合为 DailyAmount 数组
    private func aggregateBillsToDailyAmounts(_ bills: [Bill], billType: String) -> [DailyAmount] {
        let calendar = Calendar.current
        let filtered = bills.filter { $0.type == billType }
        let grouped = Dictionary(grouping: filtered) { bill in
            calendar.startOfDay(for: bill.date ?? Date())
        }
        return grouped.map { date, dayBills in
            let sum = dayBills.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
            return DailyAmount(date: date, value: sum)
        }
        .sorted { $0.date < $1.date }
    }

    func testTrendChartViewInstantiation() {
        // 构造近 7 天有数据的 series
        let calendar = Calendar.current
        let today = Date()
        var series: [DailyAmount] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                series.append(DailyAmount(date: date, value: Double(i * 30)))
            }
        }

        // TrendChartView 应能正常初始化（不 crash）
        let chartView = TendencyChartView(
            series: series,
            accent: .red,
            visibleDays: 7,
            isHourly: false,
            scrollBounds: (series.map(\.date).min() ?? today)...(series.map(\.date).max() ?? today),
            selectedDate: .constant(nil),
            scrollPosition: .constant(today)
        )
        XCTAssertNotNil(chartView)
    }

    func testTrendCardInstantiation() {
        let calendar = Calendar.current
        let today = Date()
        var series: [DailyAmount] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                series.append(DailyAmount(date: date, value: Double(i * 20)))
            }
        }

        // TrendCard 应能正常初始化（不 crash）
        let card = TrendCard(
            titleKey: "tendency.expense",
            accent: .red,
            billType: "expenditure",
            allSeries: series,
            allBills: [],
            span: .constant(SpanOption.all[1]),
            selectedDate: .constant(nil),
            scrollPosition: .constant(today)
        )
        XCTAssertNotNil(card)
    }

    func testTrendDataAggregationByDay() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // 今日两笔支出：30 + 20 = 50
        let bill1 = Bill(context: context)
        bill1.id = UUID()
        bill1.amount = NSDecimalNumber(string: "30")
        bill1.type = "expenditure"
        bill1.date = today
        bill1.createdBy = "test@example.com"
        bill1.createdAt = Date()

        let bill2 = Bill(context: context)
        bill2.id = UUID()
        bill2.amount = NSDecimalNumber(string: "20")
        bill2.type = "expenditure"
        bill2.date = today
        bill2.createdBy = "test@example.com"
        bill2.createdAt = Date()

        // 昨日一笔支出：15
        let bill3 = Bill(context: context)
        bill3.id = UUID()
        bill3.amount = NSDecimalNumber(string: "15")
        bill3.type = "expenditure"
        bill3.date = yesterday
        bill3.createdBy = "test@example.com"
        bill3.createdAt = Date()

        try? context.save()

        let series = aggregateBillsToDailyAmounts([bill1, bill2, bill3], billType: "expenditure")

        // 验证聚合结果：应有 2 个日期点
        XCTAssertEqual(series.count, 2, "应按日期聚合为 2 个数据点")

        let todayTotal = series.first { calendar.isDate($0.date, inSameDayAs: today) }?.value ?? 0
        let yesterdayTotal = series.first { calendar.isDate($0.date, inSameDayAs: yesterday) }?.value ?? 0
        XCTAssertEqual(todayTotal, 50.0, accuracy: 0.001, "今日支出聚合应为 50")
        XCTAssertEqual(yesterdayTotal, 15.0, accuracy: 0.001, "昨日支出聚合应为 15")
    }

    func testTrendChartMetricsCalculation() {
        // 构造含零值和负值的 series，验证平均值计算
        let calendar = Calendar.current
        let today = Date()
        var series: [DailyAmount] = []
        for i in 0..<5 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                series.append(DailyAmount(date: date, value: Double(i * 20)))
            }
        }

        // 模拟 TrendCard 的 metricsSeries 计算逻辑
        let values = series.map(\.value)
        let total = values.reduce(0, +)
        let nonZero = values.filter { $0 > 0 }
        let avg = nonZero.isEmpty ? 0 : nonZero.reduce(0, +) / Double(nonZero.count)

        XCTAssertEqual(total, 200.0, accuracy: 0.001, "5天总和应为 0+20+40+60+80 = 200")
        XCTAssertEqual(avg, 50.0, accuracy: 0.001, "平均值应为 (20+40+60+80)/4 = 50")
    }

    func testTrendChartEmptyData() {
        let today = Date()
        let emptySeries: [DailyAmount] = []

        let chartView = TendencyChartView(
            series: emptySeries,
            accent: .blue,
            visibleDays: 30,
            isHourly: false,
            scrollBounds: today...today,
            selectedDate: .constant(nil),
            scrollPosition: .constant(today)
        )
        XCTAssertNotNil(chartView, "空数据的图表也应能正常初始化")
    }

    // MARK: - UserProfile 模型测试

    func testUserProfileCreation() {
        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.userIdentifier = "test_user_123"
        profile.email = "test@example.com"
        profile.nickname = "测试用户"
        profile.monthlyBudget = 5000
        profile.createdAt = Date()
        profile.updatedAt = Date()

        XCTAssertNoThrow(try context.save())

        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "userIdentifier == %@", "test_user_123")
        let results = try? context.fetch(request)
        XCTAssertEqual(results?.count, 1)
        XCTAssertEqual(results?.first?.monthlyBudget, 5000)
    }

    // MARK: - 边界情况测试

    func testBillWithNilAmount() {
        let bill = Bill(context: context)
        bill.id = UUID()
        bill.amount = nil
        bill.type = "expenditure"
        bill.date = Date()
        bill.createdBy = "test@example.com"

        let amt = bill.amount?.doubleValue ?? 0
        XCTAssertEqual(amt, 0.0, "nil amount 应返回 0.0")
    }
}

// MARK: - 隐私遮罩（进入后台整页模糊）测试

/// 覆盖「仅在用户开启应用锁时才启用后台模糊」这一开关逻辑
@MainActor
final class PrivacyShieldTests: XCTestCase {

    private let lockKey = "BiometricLockEnabled"

    /// 在指定开关状态下执行断言，结束后恢复原始设置
    private func withLockSetting(_ enabled: Bool, _ body: (BiometricLockManager) -> Void) {
        let manager = BiometricLockManager.shared
        let original = UserDefaults.standard.bool(forKey: lockKey)
        UserDefaults.standard.set(enabled, forKey: lockKey)
        body(manager)
        UserDefaults.standard.set(original, forKey: lockKey)
        manager.deactivatePrivacyShield()
    }

    func testShieldIgnoredWhenLockDisabled() {
        withLockSetting(false) { manager in
            manager.activatePrivacyShield()
            XCTAssertFalse(manager.isPrivacyShieldActive, "未开启应用锁时不应启用隐私遮罩")
            XCTAssertFalse(manager.shouldBlurForPrivacy, "未开启应用锁时不应模糊页面")
        }
    }

    func testShieldActivatedWhenLockEnabled() {
        withLockSetting(true) { manager in
            manager.activatePrivacyShield()
            XCTAssertTrue(manager.isPrivacyShieldActive, "开启应用锁后进入后台应立即启用隐私遮罩")
            XCTAssertTrue(manager.shouldBlurForPrivacy, "开启应用锁后应模糊页面内容")
        }
    }

    func testDeactivateClearsShield() {
        withLockSetting(true) { manager in
            manager.activatePrivacyShield()
            XCTAssertTrue(manager.isPrivacyShieldActive)

            manager.deactivatePrivacyShield()
            XCTAssertFalse(manager.isPrivacyShieldActive, "回到前台后应解除隐私遮罩")
        }
    }
}

// MARK: - 本地化与名言数据回归

@MainActor
final class LocalizationRegressionTests: XCTestCase {

    private let languages = ["zh-Hans", "zh-Hant", "en", "ja"]
    private let criticalKeys = [
        "common.ok", "common.confirm", "common.cancel",
        "home.title", "home.change_quote", "home.surplus", "home.income_label",
        "home.period.title", "home.period.this_month", "home.period.last_month",
        "home.period.this_year", "home.period.count_value", "home.quote.title",
        // 登录/注册错误提示（曾只有简体中文，非简体语言下会显示原始 key）
        "auth.invalid_email", "auth.invalid_phone", "auth.invalid_credentials",
        "auth.password_too_short", "auth.password_not_match", "auth.no_account",
        "auth.email_empty", "auth.phone_empty", "auth.nickname_empty",
        "auth.current_password_wrong", "auth.reset_account_not_match",
        "profile.change_signature", "profile.signature_placeholder", "profile.signature_too_long"
    ]

    private func localized(_ key: String, language: String) -> String? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    /// 关键 key 在四种语言里都必须能解析出真实译文（值不能等于 key）
    func testCriticalKeysHaveTranslations() {
        for language in languages {
            for key in criticalKeys {
                let value = localized(key, language: language)
                XCTAssertNotNil(value, "\(language) 缺少语言包")
                XCTAssertNotEqual(value, key, "\(language) 的 \(key) 未配置译文（界面会显示原始 key）")
            }
        }
    }

    /// 四种语言包必须包含完全相同的 key 集合（防止漏翻译）
    func testLanguagePacksHaveIdenticalKeys() throws {
        var keySets: [String: Set<String>] = [:]
        for language in languages {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"),
                                     "\(language) 语言包缺失")
            let bundle = try XCTUnwrap(Bundle(path: path))
            let stringsPath = try XCTUnwrap(bundle.path(forResource: "Localizable", ofType: "strings"))
            let dict = try XCTUnwrap(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
            keySets[language] = Set(dict.keys)
        }

        let reference = try XCTUnwrap(keySets["zh-Hans"])
        for (language, keys) in keySets where language != "zh-Hans" {
            let missing = reference.subtracting(keys).sorted()
            let extra = keys.subtracting(reference).sorted()
            XCTAssertTrue(missing.isEmpty, "\(language) 缺少 key: \(missing.prefix(5))")
            XCTAssertTrue(extra.isEmpty, "\(language) 多出 key: \(extra.prefix(5))")
        }
    }
}

// MARK: - AppleLanguages 同步（让系统本地化解析跟随 App 内语言）

// MARK: - 个性签名校验

// MARK: - 数字键盘表达式逻辑（回归：带小数金额 + 运算符后无法继续输入）

// MARK: - 分类占比聚合（趋势页饼图）

// MARK: - 编辑账单的类型 / 分类联动规则

@MainActor
final class BillEditRulesTests: XCTestCase {

    func testCategoryAfterTypeChange() {
        XCTAssertNil(BillEditRules.categoryAfterTypeChange(to: "expenditure"), "切到支出应清空分类")
        XCTAssertNil(BillEditRules.categoryAfterTypeChange(to: "income"), "切到收入应清空分类")
        XCTAssertEqual(BillEditRules.categoryAfterTypeChange(to: "transfer"), "transfer", "转账分类固定")
    }

    func testValidityPerType() {
        XCTAssertTrue(BillEditRules.isValid("餐饮", for: "expenditure"))
        XCTAssertFalse(BillEditRules.isValid("餐饮", for: "income"), "收入不能使用餐饮分类")
        XCTAssertTrue(BillEditRules.isValid("工资", for: "income"))
        XCTAssertFalse(BillEditRules.isValid("工资", for: "expenditure"))
        XCTAssertTrue(BillEditRules.isValid("transfer", for: "transfer"))
        XCTAssertFalse(BillEditRules.isValid("餐饮", for: "transfer"))
        XCTAssertFalse(BillEditRules.isValid(nil, for: "expenditure"))
        XCTAssertFalse(BillEditRules.isValid("", for: "expenditure"))
        XCTAssertFalse(BillEditRules.isValid("不存在的分类", for: "expenditure"))
    }

    func testNormalizationForExistingBills() {
        XCTAssertNil(BillEditRules.normalizedCategory("餐饮", for: "income"), "跨类型脏数据按未选择处理")
        XCTAssertEqual(BillEditRules.normalizedCategory("餐饮", for: "expenditure"), "餐饮")
        XCTAssertEqual(BillEditRules.normalizedCategory(nil, for: "transfer"), "transfer")
        XCTAssertEqual(BillEditRules.normalizedCategory("餐饮", for: "transfer"), "transfer")
    }
}

@MainActor
final class CategoryBreakdownTests: XCTestCase {

    private var persistenceController: PersistenceController!
    private var context: NSManagedObjectContext!
    private let calendar = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        persistenceController = nil
        try super.tearDownWithError()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @discardableResult
    private func makeBill(_ amount: Decimal, type: String, category: String?, on date: Date) -> Bill {
        let bill = Bill(context: context)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(decimal: amount)
        bill.type = type
        bill.category = category
        bill.date = date
        bill.createdBy = "test@example.com"
        bill.createdAt = date
        bill.updatedAt = date
        return bill
    }

    private func fetchBills() throws -> [Bill] {
        try context.fetch(Bill.fetchRequest())
    }

    /// 窗口 = 最近 7 天（含今天）：第 8 天的数据不计入
    func testWindowCoversTodayAndLastNDays() throws {
        let now = date(2026, 3, 10)
        makeBill(10, type: "expenditure", category: "餐饮", on: date(2026, 3, 10)) // 今天 ✓
        makeBill(20, type: "expenditure", category: "餐饮", on: date(2026, 3, 4))  // 第 7 天 ✓
        makeBill(40, type: "expenditure", category: "餐饮", on: date(2026, 3, 3))  // 第 8 天 ✗
        try context.save()

        let slices = CategoryBreakdown.slices(bills: try fetchBills(), type: "expenditure", days: 7,
                                              calendar: calendar, now: now)
        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices[0].amount, 30, accuracy: 0.001)
        XCTAssertEqual(slices[0].count, 2)
    }

    /// 分组求和 + 金额降序（同额按 rawValue 升序）
    func testGroupingAndSorting() throws {
        let now = date(2026, 3, 10)
        makeBill(10, type: "expenditure", category: "餐饮", on: date(2026, 3, 10))
        makeBill(20, type: "expenditure", category: "餐饮", on: date(2026, 3, 9))
        makeBill(50, type: "expenditure", category: "购物", on: date(2026, 3, 8))
        makeBill(50, type: "expenditure", category: "交通", on: date(2026, 3, 7))
        try context.save()

        let slices = CategoryBreakdown.slices(bills: try fetchBills(), type: "expenditure", days: 30,
                                              calendar: calendar, now: now)
        XCTAssertEqual(slices.count, 3)
        XCTAssertEqual(slices[0].amount, 50, accuracy: 0.001)
        XCTAssertEqual(slices[1].amount, 50, accuracy: 0.001)
        // 同额时按 rawValue 升序：「交通」< 「购物」
        XCTAssertTrue(slices[1].rawValue < slices[2].rawValue)

        let food = slices.first { $0.rawValue == "餐饮" }
        XCTAssertEqual(food?.amount ?? 0, 30, accuracy: 0.001)
        XCTAssertEqual(food?.count, 2)
    }

    /// 类型隔离：查询支出时不包含收入与转账
    func testTypeIsolation() throws {
        let now = date(2026, 3, 10)
        makeBill(10, type: "expenditure", category: "餐饮", on: now)
        makeBill(99, type: "income", category: "工资", on: now)
        makeBill(88, type: "transfer", category: "transfer", on: now)
        try context.save()

        let expense = CategoryBreakdown.slices(bills: try fetchBills(), type: "expenditure", days: 30,
                                               calendar: calendar, now: now)
        XCTAssertEqual(expense.map(\.rawValue), ["餐饮"])
        XCTAssertEqual(CategoryBreakdown.total(of: expense), 10, accuracy: 0.001)

        let income = CategoryBreakdown.slices(bills: try fetchBills(), type: "income", days: 30,
                                              calendar: calendar, now: now)
        XCTAssertEqual(income.map(\.rawValue), ["工资"])
    }

    /// 空数据与占比格式（最多两位小数）
    func testEmptyAndPercentFormat() throws {
        let now = date(2026, 3, 10)
        let empty = CategoryBreakdown.slices(bills: try fetchBills(), type: "expenditure", days: 7,
                                             calendar: calendar, now: now)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(CategoryBreakdown.total(of: empty), 0, accuracy: 0.001)

        makeBill(43.25, type: "expenditure", category: "餐饮", on: now)
        makeBill(56.75, type: "expenditure", category: "购物", on: now)
        try context.save()

        let slices = CategoryBreakdown.slices(bills: try fetchBills(), type: "expenditure", days: 7,
                                              calendar: calendar, now: now)
        let total = CategoryBreakdown.total(of: slices)
        XCTAssertEqual(total, 100, accuracy: 0.001)
        let percentText = AppNumberFormat.percent((slices.first { $0.rawValue == "餐饮" }?.amount ?? 0) / total)
        let digits = percentText.filter { $0.isNumber || $0 == "." }
        XCTAssertEqual(digits, "43.25")
    }
}

@MainActor
final class NumberPadExpressionTests: XCTestCase {

    /// 本次修复的 bug：先输入带小数的金额，按运算符后仍能继续输入数字
    func testDigitsStillEnterableAfterOperatorWithDecimalAmount() {
        var text = NumberPadExpression.placeholder
        for input in ["1", "2", ".", "5"] {
            text = NumberPadExpression.append(input, to: text)
        }
        XCTAssertEqual(text, "12.5")

        text = NumberPadExpression.applyOperator(primary: "+", alternate: "×", to: text)
        XCTAssertEqual(text, "12.5+")

        // 修复前这里会被「整串表达式小数位已满」的判断拦掉
        text = NumberPadExpression.append("3", to: text)
        XCTAssertEqual(text, "12.5+3")

        text = NumberPadExpression.append("0", to: text)
        XCTAssertEqual(text, "12.5+30")
    }

    func testFractionLimitOnlyAppliesToCurrentSegment() {
        var text = "12.5"
        text = NumberPadExpression.append("0", to: text)
        XCTAssertEqual(text, "12.50")

        // 当前数字已满两位小数 → 拒绝
        text = NumberPadExpression.append("1", to: text)
        XCTAssertEqual(text, "12.50")

        // 运算符之后是新的数字段，可以继续输入
        text = NumberPadExpression.applyOperator(primary: "+", alternate: "×", to: text)
        text = NumberPadExpression.append("7", to: text)
        XCTAssertEqual(text, "12.50+7")
    }

    func testOperatorTogglesOnSecondTap() {
        var text = NumberPadExpression.append("8", to: NumberPadExpression.placeholder)
        text = NumberPadExpression.applyOperator(primary: "+", alternate: "×", to: text)
        XCTAssertEqual(text, "8+", "第一次按应插入主运算符")

        text = NumberPadExpression.applyOperator(primary: "+", alternate: "×", to: text)
        XCTAssertEqual(text, "8×", "再按一次切换到备用运算符")

        text = NumberPadExpression.applyOperator(primary: "-", alternate: "÷", to: text)
        XCTAssertEqual(text, "8-", "换另一个按钮应替换为它的主运算符")
    }

    func testDecimalRightAfterOperatorStartsNewNumber() {
        var text = "12"
        text = NumberPadExpression.applyOperator(primary: "+", alternate: "×", to: text)
        text = NumberPadExpression.append(".", to: text)
        XCTAssertEqual(text, "12+0.")
    }

    func testPlaceholderAndLeadingZeroHandling() {
        XCTAssertEqual(NumberPadExpression.append("5", to: NumberPadExpression.placeholder), "5")
        XCTAssertEqual(NumberPadExpression.append(".", to: NumberPadExpression.placeholder), "0.")
        XCTAssertEqual(NumberPadExpression.append("5", to: "0"), "5")
        XCTAssertEqual(NumberPadExpression.append(".", to: "12.5"), "12.5", "重复小数点应被忽略")
    }

    func testIntegerDigitLimit() {
        let long = String(repeating: "9", count: NumberPadExpression.maxIntegerDigits)
        XCTAssertEqual(NumberPadExpression.append("9", to: long), long)
    }

    func testDeleteBehaviour() {
        XCTAssertEqual(NumberPadExpression.deleteLast(from: "12+3"), "12+")
        XCTAssertEqual(NumberPadExpression.deleteLast(from: "1"), NumberPadExpression.placeholder)
        XCTAssertEqual(NumberPadExpression.deleteLast(from: NumberPadExpression.placeholder),
                       NumberPadExpression.placeholder)
    }

    func testPercentKeepsTwoDecimalsForPlainNumber() {
        XCTAssertEqual(NumberPadExpression.applyPercent(to: "12.5"), "0.12")
        XCTAssertEqual(NumberPadExpression.applyPercent(to: "12+3"), "12+3", "表达式含运算符时不处理")
    }

    /// 键盘输入的表达式应能正确算出结果（用户要的「能做运算」）
    func testExpressionEvaluation() {
        let view = AddBillView()
        XCTAssertEqual(view.parseExpression("12.5+30"), 42.5, accuracy: 0.001)
        XCTAssertEqual(view.parseExpression("9-4"), 5, accuracy: 0.001)
        XCTAssertEqual(view.parseExpression("10×3"), 30, accuracy: 0.001)
        XCTAssertEqual(view.parseExpression("100÷4"), 25, accuracy: 0.001)
        XCTAssertEqual(view.parseExpression("88"), 88, accuracy: 0.001)
    }
}

@MainActor
final class SignatureValidationTests: XCTestCase {

    func testEmptySignatureClearsValue() {
        XCTAssertEqual(AuthManager.validateSignature("   "), .valid(nil))
    }

    func testSignatureTrimsWhitespace() {
        XCTAssertEqual(AuthManager.validateSignature("  记录每一天  "), .valid("记录每一天"))
    }

    func testSignatureLengthBoundary() {
        let exactlyLimit = String(repeating: "字", count: AuthManager.signatureMaxLength)
        XCTAssertEqual(AuthManager.validateSignature(exactlyLimit), .valid(exactlyLimit))

        let tooLong = String(repeating: "字", count: AuthManager.signatureMaxLength + 1)
        XCTAssertEqual(AuthManager.validateSignature(tooLong), .tooLong)
    }
}

@MainActor
final class LocalizationSyncTests: XCTestCase {

    private let appleLanguagesKey = "AppleLanguages"
    private let appLanguageKey = "app_language"

    /// 只读取 App 自身持久域中的 AppleLanguages（`UserDefaults.standard` 还会返回系统域提供的默认值）
    private func storedAppleLanguages() -> [String]? {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let domain = UserDefaults.standard.persistentDomain(forName: bundleID) else { return nil }
        return domain[appleLanguagesKey] as? [String]
    }

    /// 执行用例后恢复 UserDefaults，避免影响其它测试
    private func withRestoredDefaults(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let originalApple = storedAppleLanguages()
        let originalApp = defaults.string(forKey: appLanguageKey)
        defer {
            if let originalApple { defaults.set(originalApple, forKey: appleLanguagesKey) }
            else { defaults.removeObject(forKey: appleLanguagesKey) }
            if let originalApp { defaults.set(originalApp, forKey: appLanguageKey) }
            else { defaults.removeObject(forKey: appLanguageKey) }
        }
        body()
    }

    func testApplyWritesAppleLanguagesForFixedLanguage() {
        withRestoredDefaults {
            // 先置为确定状态（模拟器/宿主 App 可能已写入过其它值）
            _ = LocalizationSync.apply(.en)

            XCTAssertTrue(LocalizationSync.apply(.ja))
            XCTAssertEqual(storedAppleLanguages(), ["ja"])

            // 幂等：重复设置相同语言不再变更
            XCTAssertFalse(LocalizationSync.apply(.ja))
        }
    }

    func testApplySystemRemovesOverride() {
        withRestoredDefaults {
            _ = LocalizationSync.apply(.en)
            XCTAssertEqual(storedAppleLanguages(), ["en"])

            XCTAssertTrue(LocalizationSync.apply(.system))
            XCTAssertNil(storedAppleLanguages(),
                         "跟随系统时应移除 AppleLanguages 覆盖")
        }
    }

    func testSyncIfNeededFollowsStoredAppLanguage() {
        withRestoredDefaults {
            UserDefaults.standard.set(AppLanguage.zhHant.rawValue, forKey: appLanguageKey)
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)

            LocalizationSync.syncIfNeeded()
            XCTAssertEqual(storedAppleLanguages(), ["zh-Hant"])

            UserDefaults.standard.set(AppLanguage.system.rawValue, forKey: appLanguageKey)
            LocalizationSync.syncIfNeeded()
            XCTAssertNil(storedAppleLanguages())
        }
    }
}

// MARK: - 概况页区间聚合（本月 / 上月 / 本年）

@MainActor
final class NumberFormatTests: XCTestCase {

    /// 只保留数字与小数点，避免不同地区格式（空格、全角符号）影响断言
    private func digits(_ text: String) -> String {
        text.filter { $0.isNumber || $0 == "." }
    }

    func testPercentKeepsAtMostTwoDecimals() {
        XCTAssertEqual(digits(AppNumberFormat.percent(0)), "0")
        XCTAssertEqual(digits(AppNumberFormat.percent(0.43)), "43")
        XCTAssertEqual(digits(AppNumberFormat.percent(0.432)), "43.2")
        XCTAssertEqual(digits(AppNumberFormat.percent(0.4325)), "43.25")
        XCTAssertEqual(digits(AppNumberFormat.percent(1.0)), "100")
    }

    func testPercentEndsWithSymbol() {
        XCTAssertTrue(AppNumberFormat.percent(0.5).contains("%"))
    }
}

@MainActor
final class PeriodSummaryTests: XCTestCase {

    private var persistenceController: PersistenceController!
    private var context: NSManagedObjectContext!
    private let calendar = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        persistenceController = nil
        try super.tearDownWithError()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @discardableResult
    private func makeBill(_ amount: Decimal, type: String, on date: Date) -> Bill {
        let bill = Bill(context: context)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(decimal: amount)
        bill.type = type
        bill.category = "测试"
        bill.date = date
        bill.createdBy = "test@example.com"
        bill.createdAt = date
        bill.updatedAt = date
        return bill
    }

    /// 跨年场景：1 月时「上月」应取到去年 12 月，去年 11 月不计入本年
    func testAggregationAcrossMonthAndYearBoundary() throws {
        let now = date(2026, 1, 15)
        let ranges = PeriodRanges.make(calendar: calendar, now: now)

        // 本月（2026-01）
        makeBill(100, type: "expenditure", on: date(2026, 1, 10))
        makeBill(500, type: "income", on: date(2026, 1, 12))
        // 上月（2025-12）
        makeBill(300, type: "expenditure", on: date(2025, 12, 20))
        // 更早（2025-11）→ 不属于本年，也不属于上月
        makeBill(999, type: "expenditure", on: date(2025, 11, 5))
        try context.save()

        let bills = try context.fetch(Bill.fetchRequest())
        let summaries = PeriodSummary.make(bills: bills, ranges: ranges)

        let thisMonth = try XCTUnwrap(summaries.first { $0.period == .thisMonth })
        XCTAssertEqual(thisMonth.income, 500)
        XCTAssertEqual(thisMonth.expense, 100)
        XCTAssertEqual(thisMonth.count, 2)
        XCTAssertEqual(thisMonth.balance, 400)

        let lastMonth = try XCTUnwrap(summaries.first { $0.period == .lastMonth })
        XCTAssertEqual(lastMonth.income, 0)
        XCTAssertEqual(lastMonth.expense, 300)
        XCTAssertEqual(lastMonth.count, 1)
        XCTAssertEqual(lastMonth.balance, -300)

        let thisYear = try XCTUnwrap(summaries.first { $0.period == .thisYear })
        XCTAssertEqual(thisYear.income, 500)
        XCTAssertEqual(thisYear.expense, 100, "去年 11 月的支出不应计入本年")
        XCTAssertEqual(thisYear.count, 2)
    }

    /// 转账计入笔数，但不计入收入 / 支出
    func testTransferCountsButHasNoAmount() throws {
        let now = date(2026, 3, 10)
        let ranges = PeriodRanges.make(calendar: calendar, now: now)

        makeBill(200, type: "expenditure", on: date(2026, 3, 2))
        makeBill(50, type: "transfer", on: date(2026, 3, 3))
        try context.save()

        let bills = try context.fetch(Bill.fetchRequest())
        let summaries = PeriodSummary.make(bills: bills, ranges: ranges)
        let thisMonth = try XCTUnwrap(summaries.first { $0.period == .thisMonth })

        XCTAssertEqual(thisMonth.count, 2, "转账应计入笔数")
        XCTAssertEqual(thisMonth.expense, 200, "转账不计入支出")
        XCTAssertEqual(thisMonth.income, 0)
    }

    /// 取数窗口必须覆盖「本月 + 上月 + 本年」
    func testFetchWindowCoversThisYearAndLastMonth() {
        let january = PeriodRanges.make(calendar: calendar, now: date(2026, 1, 15))
        XCTAssertLessThanOrEqual(january.fetchWindow.lowerBound, january.lastMonth.lowerBound)
        XCTAssertLessThanOrEqual(january.fetchWindow.lowerBound, january.thisYear.lowerBound)
        XCTAssertEqual(january.fetchWindow.upperBound, january.today.upperBound)

        let july = PeriodRanges.make(calendar: calendar, now: date(2026, 7, 20))
        XCTAssertEqual(july.fetchWindow.lowerBound, july.thisYear.lowerBound, "非 1 月时窗口起点应为本年 1 月 1 日")
    }
}

@MainActor
final class DailySentenceDataTests: XCTestCase {

    /// 名言 JSON 清理掉图片地址后仍必须可解码
    func testEconomicQuotesDecoding() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "EconomicQuotes", withExtension: "json"),
            "App bundle 中缺少 EconomicQuotes.json"
        )
        let data = try Data(contentsOf: url)
        let list = try JSONDecoder().decode([DailySentence].self, from: data)

        XCTAssertEqual(list.count, 100, "名言条数应为 100")
        XCTAssertTrue(list.allSatisfy { !$0.content.isEmpty && !$0.note.isEmpty },
                      "名言内容与作者都不应为空")
    }
}
