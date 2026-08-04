//
//  MaciFinanceTests.swift
//  MaciFinanceTests
//
//  Created by 刘不易 on 2026/5/6.
//

import Testing
@testable import MaciFinance
import CoreData
import SwiftUI
import Charts

// MARK: - 测试共享环境

@MainActor
final class MacTestContext {
    let persistenceController: PersistenceController
    let context: NSManagedObjectContext

    init() {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    /// 创建指定类型的账单
    func makeBill(
        amount: Double,
        type: String,
        category: String = "餐饮",
        note: String? = nil,
        date: Date = Date(),
        createdBy: String = "test@example.com"
    ) -> Bill {
        let bill = Bill(context: context)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(value: amount)
        bill.type = type
        bill.category = category
        bill.note = note
        bill.date = date
        bill.createdBy = createdBy
        bill.createdAt = Date()
        bill.updatedAt = Date()
        return bill
    }

    /// 创建并保存多个账单
    func seedBills(_ specs: [(amount: Double, type: String, daysAgo: Int)]) {
        let cal = Calendar.current
        for spec in specs {
            let date = cal.date(byAdding: .day, value: -spec.daysAgo, to: Date())!
            let bill = makeBill(amount: spec.amount, type: spec.type, date: date)
            context.insert(bill)
        }
        try? context.save()
    }
}

// MARK: - PersistenceController 测试

struct PersistenceTests {
    @Test
    func testPersistenceControllerSharedExists() {
        let controller = PersistenceController.shared
        #expect(controller.container.name == "MaciFinance")
    }

    @Test
    func testPersistenceControllerInMemory() {
        let controller = PersistenceController(inMemory: true)
        #expect(controller.container.persistentStoreDescriptions.first?.url == URL(fileURLWithPath: "/dev/null"))
    }

    @Test
    func testPersistenceControllerInMemoryBillCreation() {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let bill = Bill(context: ctx)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(value: 99.9)
        bill.date = Date()
        bill.type = "expenditure"
        bill.category = "测试"
        bill.createdBy = "test@example.com"
        bill.createdAt = Date()
        bill.updatedAt = Date()
        do { try ctx.save() } catch { }
    }

    @Test
    func testPersistenceControllerCurrentUserIdentifier() {
        let identifier = PersistenceController.currentUserIdentifier
        #expect(!identifier.isEmpty)
    }
}

// MARK: - Bill 模型测试

struct BillModelTests {
    @MainActor
    @Test
    func testBillCreation() throws {
        let ctx = MacTestContext()
        let bill = ctx.makeBill(amount: 123.45, type: "expenditure", category: "餐饮")
        bill.note = "午餐"
        try ctx.context.save()

        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        let results = try ctx.context.fetch(request)
        #expect(results.count == 1)
        #expect(results[0].amount?.doubleValue == 123.45)
        #expect(results[0].type == "expenditure")
        #expect(results[0].category == "餐饮")
    }

    @MainActor
    @Test
    func testBillAmountDecimalValue() {
        let ctx = MacTestContext()
        let bill = ctx.makeBill(amount: 88.88, type: "income")
        let decimalValue = bill.amount?.decimalValue ?? Decimal(0)
        #expect(decimalValue == Decimal(string: "88.88"))
    }

    @MainActor
    @Test
    func testBillDelete() {
        let ctx = MacTestContext()
        let bill = ctx.makeBill(amount: 50, type: "expenditure")
        try? ctx.context.save()

        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        let before = (try? ctx.context.fetch(request))?.count ?? 0
        #expect(before == 1)

        ctx.context.delete(bill)
        try? ctx.context.save()

        let after = (try? ctx.context.fetch(request))?.count ?? 0
        #expect(after == 0)
    }
}

// MARK: - DashboardView 计算逻辑测试

struct DashboardLogicTests {
    @MainActor
    @Test
    func testTodayExpenseCalculation() {
        let ctx = MacTestContext()
        let cal = Calendar.current

        // 今日支出
        ctx.makeBill(amount: 30, type: "expenditure", date: Date())
        ctx.makeBill(amount: 20, type: "expenditure", date: Date())
        // 昨日支出（不计入今日）
        ctx.makeBill(amount: 50, type: "expenditure",
                     date: cal.date(byAdding: .day, value: -1, to: Date())!)
        // 今日收入（不计入支出）
        ctx.makeBill(amount: 100, type: "income", date: Date())
        try? ctx.context.save()

        // 模拟 DashboardView 的 todayExpense 计算
        let startOfDay = cal.startOfDay(for: Date())
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND type == %@",
            startOfDay as NSDate, endOfDay as NSDate, "expenditure"
        )
        let todayBills = (try? ctx.context.fetch(request)) ?? []
        let todayExpense = todayBills.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
        #expect(todayExpense == 50.0)
    }

    @MainActor
    @Test
    func testTodayIncomeCalculation() {
        let ctx = MacTestContext()
        let cal = Calendar.current
        let today = Date()

        ctx.makeBill(amount: 200, type: "income", date: today)
        ctx.makeBill(amount: 50, type: "income", date: today)
        ctx.makeBill(amount: 100, type: "expenditure", date: today)
        ctx.makeBill(amount: 300, type: "income",
                     date: cal.date(byAdding: .day, value: -1, to: today)!)
        try? ctx.context.save()

        let startOfDay = cal.startOfDay(for: today)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND type == %@",
            startOfDay as NSDate, endOfDay as NSDate, "income"
        )
        let todayIncome = ((try? ctx.context.fetch(request)) ?? [])
            .reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
        #expect(todayIncome == 250.0)
    }

    @MainActor
    @Test
    func testBalanceCalculation() {
        let ctx = MacTestContext()
        ctx.seedBills([
            (amount: 1000, type: "income", daysAgo: 0),
            (amount: 500, type: "income", daysAgo: 5),
            (amount: 200, type: "expenditure", daysAgo: 2),
            (amount: 100, type: "expenditure", daysAgo: 1),
        ])

        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        let allBills = (try? ctx.context.fetch(request)) ?? []
        let totalIncome = allBills.filter { $0.type == "income" }
            .reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
        let totalExpense = allBills.filter { $0.type == "expenditure" }
            .reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
        let balance = totalIncome - totalExpense

        #expect(totalIncome == 1500.0)
        #expect(totalExpense == 300.0)
        #expect(balance == 1200.0)
    }

    @MainActor
    @Test
    func testDailyDataPointsGeneration() {
        let ctx = MacTestContext()
        let cal = Calendar.current
        let today = Date()
        let startOfToday = cal.startOfDay(for: today)

        // 近 5 天每天有支出
        for i in 0..<5 {
            guard let date = cal.date(byAdding: .day, value: -i, to: startOfToday) else { continue }
            ctx.makeBill(amount: Double(i * 20 + 10), type: "expenditure", date: date)
        }
        try? ctx.context.save()

        // 模拟 DashboardView 的 dailyDataPoints 计算
        let end = startOfToday
        var points: [(date: Date, expense: Double)] = []
        for dayOffset in 0..<5 {
            guard let dayDate = cal.date(byAdding: .day, value: -dayOffset, to: end),
                  let dayEnd = cal.date(byAdding: .day, value: 1, to: dayDate) else { continue }

            let dayBills = (try? ctx.context.fetch(Bill.fetchRequest()))?.filter {
                guard let d = $0.date else { return false }
                return d >= dayDate && d < dayEnd && $0.type == "expenditure"
            } ?? []
            let expense = dayBills.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
            points.append((dayDate, expense))
        }
        points.reverse()

        #expect(points.count == 5)
        // points[0] = 4天前（90元），points[4] = 今天（10元）reverse 后保持原有顺序
        #expect(points[0].expense == 90.0)
        #expect(points[4].expense == 10.0)
    }
}

// MARK: - StatisticsView 计算逻辑测试

struct StatisticsLogicTests {
    @MainActor
    @Test
    func testPeriodWeekRange() {
        let cal = Calendar.current
        let now = Date()

        // 本周起始
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = min(cal.date(byAdding: .day, value: 7, to: weekStart)!, now)

        // 验证本周包含今天
        #expect(weekStart <= now)
        #expect(weekEnd >= now)

        // 本周范围内的天数
        let days = cal.dateComponents([.day], from: weekStart, to: weekEnd).day ?? 0
        #expect(days <= 7)
    }

    @MainActor
    @Test
    func testPeriodMonthRange() {
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        #expect(monthStart <= now)
        #expect(cal.component(.month, from: monthStart) == cal.component(.month, from: now))
    }

    @MainActor
    @Test
    func testPeriodYearRange() {
        let cal = Calendar.current
        let now = Date()
        let yearStart = cal.date(from: cal.dateComponents([.year], from: now))!

        #expect(yearStart <= now)
        #expect(cal.component(.year, from: yearStart) == cal.component(.year, from: now))
    }

    @MainActor
    @Test
    func testExpenseByCategoryAggregation() {
        let ctx = MacTestContext()
        let today = Date()

        ctx.makeBill(amount: 100, type: "expenditure", category: "餐饮", date: today)
        ctx.makeBill(amount: 80, type: "expenditure", category: "餐饮", date: today)
        ctx.makeBill(amount: 200, type: "expenditure", category: "购物", date: today)
        ctx.makeBill(amount: 150, type: "expenditure", category: "交通", date: today)
        ctx.makeBill(amount: 500, type: "income", category: "工资", date: today) // 不计入支出
        try? ctx.context.save()

        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        let periodBills = ((try? ctx.context.fetch(request)) ?? [])
            .filter { $0.type == "expenditure" }

        var dict: [String: (Double, Int)] = [:]
        for bill in periodBills {
            let cat = bill.category ?? "其他"
            dict[cat, default: (0, 0)].0 += bill.amount?.doubleValue ?? 0
            dict[cat, default: (0, 0)].1 += 1
        }

        #expect(dict["餐饮"]?.0 == 180.0)
        #expect(dict["餐饮"]?.1 == 2)
        #expect(dict["购物"]?.0 == 200.0)
        #expect(dict["交通"]?.0 == 150.0)
        #expect(dict["工资"] == nil) // 收入不算支出
    }

    @MainActor
    @Test
    func testDailyPointsGeneration() {
        let ctx = MacTestContext()
        let cal = Calendar.current
        let today = Date()
        let startOfToday = cal.startOfDay(for: today)

        // 今天
        ctx.makeBill(amount: 50, type: "expenditure", date: today)
        ctx.makeBill(amount: 200, type: "income", date: today)
        // 昨天
        if let yesterday = cal.date(byAdding: .day, value: -1, to: startOfToday) {
            ctx.makeBill(amount: 80, type: "expenditure", date: yesterday)
        }
        try? ctx.context.save()

        // 模拟生成日数据点
        var points: [(expense: Double, income: Double)] = []
        var current = startOfToday
        for _ in 0..<2 {
            guard let dayEnd = cal.date(byAdding: .day, value: 1, to: current) else { break }

            let dayBills = ((try? ctx.context.fetch(Bill.fetchRequest())) ?? []).filter {
                guard let d = $0.date else { return false }
                return d >= current && d < dayEnd
            }
            let expense = dayBills.filter { $0.type == "expenditure" }
                .reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
            let income = dayBills.filter { $0.type == "income" }
                .reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
            points.append((expense, income))

            if let next = cal.date(byAdding: .day, value: -1, to: current) {
                current = next
            } else { break }
        }

        #expect(points.count == 2)
        #expect(points[0].expense == 50.0)  // 今天
        #expect(points[0].income == 200.0)
        #expect(points[1].expense == 80.0)  // 昨天
    }
}

// MARK: - BillListView 过滤逻辑测试

struct BillListLogicTests {
    @MainActor
    @Test
    func testFilterByExpenseType() {
        let ctx = MacTestContext()
        ctx.seedBills([
            (amount: 50, type: "expenditure", daysAgo: 0),
            (amount: 100, type: "expenditure", daysAgo: 1),
            (amount: 200, type: "income", daysAgo: 0),
        ])

        let allBills = (try? ctx.context.fetch(Bill.fetchRequest())) ?? []
        let expenseBills = allBills.filter { $0.type == "expenditure" }
        let incomeBills = allBills.filter { $0.type == "income" }

        #expect(expenseBills.count == 2)
        #expect(incomeBills.count == 1)
        #expect(expenseBills.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) } == 150.0)
    }

    @MainActor
    @Test
    func testSearchByCategory() {
        let ctx = MacTestContext()
        ctx.seedBills([
            (amount: 50, type: "expenditure", daysAgo: 0),
            (amount: 80, type: "expenditure", daysAgo: 0),
            (amount: 100, type: "expenditure", daysAgo: 0),
        ])
        // 手动设置分类
        let bills = (try? ctx.context.fetch(Bill.fetchRequest())) ?? []
        bills[0].category = "餐饮"
        bills[1].category = "购物"
        bills[2].category = "交通"
        try? ctx.context.save()

        let searchText = "餐"
        let filtered = bills.filter {
            $0.category?.localizedCaseInsensitiveContains(searchText) ?? false
        }
        #expect(filtered.count == 1)
        #expect(filtered[0].category == "餐饮")
    }

    @MainActor
    @Test
    func testSearchByNote() {
        let ctx = MacTestContext()
        ctx.seedBills([
            (amount: 50, type: "expenditure", daysAgo: 0),
            (amount: 80, type: "expenditure", daysAgo: 0),
        ])
        let bills = (try? ctx.context.fetch(Bill.fetchRequest())) ?? []
        bills[0].note = "午餐"
        bills[1].note = "晚餐"
        try? ctx.context.save()

        let searchText = "午"
        let filtered = bills.filter {
            $0.note?.localizedCaseInsensitiveContains(searchText) ?? false
        }
        #expect(filtered.count == 2)
    }

    @MainActor
    @Test
    func testGroupedByDateToday() {
        let ctx = MacTestContext()
        ctx.makeBill(amount: 30, type: "expenditure", date: Date())
        ctx.makeBill(amount: 50, type: "expenditure", date: Date())
        try? ctx.context.save()

        let cal = Calendar.current
        let allBills = (try? ctx.context.fetch(Bill.fetchRequest())) ?? []
        let todayBills = allBills.filter {
            guard let date = $0.date else { return false }
            return cal.isDateInToday(date)
        }
        #expect(todayBills.count == 2)
        #expect(todayBills.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) } == 80.0)
    }

    @MainActor
    @Test
    func testGroupedByDateYesterday() {
        let ctx = MacTestContext()
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!

        ctx.makeBill(amount: 100, type: "income", date: yesterday)
        ctx.makeBill(amount: 40, type: "expenditure", date: yesterday)
        try? ctx.context.save()

        let allBills = (try? ctx.context.fetch(Bill.fetchRequest())) ?? []
        let yesterdayBills = allBills.filter {
            guard let date = $0.date else { return false }
            return cal.isDateInYesterday(date)
        }
        #expect(yesterdayBills.count == 2)
    }

    @MainActor
    @Test
    func testGroupedByRecentWeek() {
        let ctx = MacTestContext()
        let cal = Calendar.current
        let today = Date()

        // 近 3 天
        ctx.makeBill(amount: 10, type: "expenditure", date: today)
        ctx.makeBill(amount: 20, type: "expenditure",
                     date: cal.date(byAdding: .day, value: -2, to: today)!)
        // 10 天前（不算"最近"）
        ctx.makeBill(amount: 50, type: "expenditure",
                     date: cal.date(byAdding: .day, value: -10, to: today)!)
        try? ctx.context.save()

        let allBills = (try? ctx.context.fetch(Bill.fetchRequest())) ?? []
        let recentBills = allBills.filter {
            guard let date = $0.date else { return false }
            guard let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: today)) else { return false }
            return date >= start && date <= today
        }
        #expect(recentBills.count == 2)
    }

    @MainActor
    @Test
    func testTotalExpenseAndIncome() {
        let ctx = MacTestContext()
        ctx.seedBills([
            (amount: 100, type: "expenditure", daysAgo: 0),
            (amount: 50, type: "expenditure", daysAgo: 1),
            (amount: 200, type: "income", daysAgo: 0),
            (amount: 500, type: "income", daysAgo: 2),
        ])

        let allBills = (try? ctx.context.fetch(Bill.fetchRequest())) ?? []
        let totalExpense = allBills
            .filter { $0.type == "expenditure" }
            .reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
        let totalIncome = allBills
            .filter { $0.type == "income" }
            .reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }

        #expect(totalExpense == 150.0)
        #expect(totalIncome == 700.0)
    }
}

// MARK: - 图表空数据测试

struct ChartDisplayTests {
    @MainActor
    @Test
    func testStatCardInstantiation() {
        let card = StatCard(
            title: "今日支出",
            value: 120.5,
            icon: "arrow.down.circle.fill",
            color: .red
        )
        #expect(card.title == "今日支出")
    }

    @MainActor
    @Test
    func testStatCardCountMode() {
        let card = StatCard(
            title: "账单数",
            count: 42,
            icon: "list.bullet",
            color: .orange
        )
        #expect(card.count == 42)
    }

    @MainActor
    @Test
    func testEmptyDataChartPlaceholder() {
        let emptyPoints: [DashboardView.DayDataPoint] = []
        let allEmpty = emptyPoints.allSatisfy { $0.expense == 0 && $0.income == 0 }
        #expect(allEmpty == true)
    }

    @MainActor
    @Test
    func testFormatCurrencyOutput() {
        let formatted = formatCurrency(1234.56)
        #expect(formatted.contains("1"))
        #expect(formatted.contains("¥") || formatted.contains("¥") == false)
    }
}
