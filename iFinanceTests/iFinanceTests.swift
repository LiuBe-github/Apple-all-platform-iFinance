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

    // MARK: - 支出分类测试

    func testExpenditureCategoryAllCases() {
        let all = ExpenditureCategory.allCases
        // 枚举中共有 21 个 case
        XCTAssertEqual(all.count, 21)
    }

    func testExpenditureCategoryRawValues() {
        XCTAssertEqual(ExpenditureCategory.foodAndBeverage.rawValue, "餐饮")
        XCTAssertEqual(ExpenditureCategory.shopping.rawValue, "购物")
        XCTAssertEqual(ExpenditureCategory.digital.rawValue, "数码")
    }

    func testExpenditureCategoryIcons() {
        XCTAssertEqual(ExpenditureCategory.foodAndBeverage.icon, "fork.knife")
        XCTAssertEqual(ExpenditureCategory.shopping.icon, "cart")
        XCTAssertEqual(ExpenditureCategory.digital.icon, "phone")
        XCTAssertEqual(ExpenditureCategory.medical.icon, "heart")
    }

    func testExpenditureCategoryLocalizedDisplayName() {
        let cat = ExpenditureCategory.foodAndBeverage
        let name = cat.localizedDisplayName
        XCTAssertFalse(name.isEmpty, "localizedDisplayName 不应为空")
    }

    // MARK: - 收入分类测试

    func testIncomeCategoryAllCases() {
        let all = IncomeCategory.allCases
        XCTAssertEqual(all.count, 10)
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
            selectedDate: .constant(nil),
            scrollPosition: .constant(today),
            chartType: .constant(.line)
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
            span: .constant(SpanOption.all[1]),
            chartType: .constant(.line),
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
            selectedDate: .constant(nil),
            scrollPosition: .constant(today),
            chartType: .constant(.bar)
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
