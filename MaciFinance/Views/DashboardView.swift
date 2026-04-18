//
//  DashboardView.swift
//  MaciFinance
//

import SwiftUI
import CoreData
import Charts

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        predicate: nil,
        animation: .default
    ) private var allBills: FetchedResults<Bill>

    // MARK: - Today's bills

    @FetchRequest private var todayBills: FetchedResults<Bill>

    init() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        _todayBills = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
            predicate: NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        )
    }

    // MARK: - This month's bills (for chart)

    private var thisMonthBills: [Bill] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return [] }
        return allBills.filter {
            guard let date = $0.date else { return false }
            return date >= monthStart && date <= now
        }
    }

    // MARK: - Computed values

    private var todayExpense: Double {
        todayBills.filter { $0.type == "expenditure" }
            .reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }

    private var todayIncome: Double {
        todayBills.filter { $0.type == "income" }
            .reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }

    private var totalExpense: Double {
        allBills.filter { $0.type == "expenditure" }
            .reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }

    private var totalIncome: Double {
        allBills.filter { $0.type == "income" }
            .reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }

    private var balance: Double {
        totalIncome - totalExpense
    }

    private var billCount: Int { allBills.count }

    // MARK: - Daily data for chart (last 30 days)

    struct DayDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let expense: Double
        let income: Double
    }

    private var dailyDataPoints: [DayDataPoint] {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        var points: [DayDataPoint] = []

        for dayOffset in 0..<30 {
            guard let dayDate = cal.date(byAdding: .day, value: -dayOffset, to: end),
                  let dayEnd = cal.date(byAdding: .day, value: 1, to: dayDate) else { continue }

            let dayBills = allBills.filter {
                guard let d = $0.date else { return false }
                return d >= dayDate && d < dayEnd
            }
            let expense = dayBills.filter { $0.type == "expenditure" }.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
            let income = dayBills.filter { $0.type == "income" }.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }

            points.append(DayDataPoint(date: dayDate, expense: expense, income: income))
        }
        return points.reversed()
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // MARK: Summary Cards
                HStack(spacing: 16) {
                    StatCard(title: "今日支出", value: todayExpense, icon: "arrow.down.circle.fill", color: .red)
                    StatCard(title: "今日收入", value: todayIncome, icon: "arrow.up.circle.fill", color: .green)
                    StatCard(title: "总余额", value: balance, icon: "yensign.circle.fill", color: .blue)
                    StatCard(title: "账单数", count: billCount, icon: "list.bullet", color: .orange)
                }

                // MARK: Overview Section
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    OverviewCard(
                        title: "总收入",
                        value: totalIncome,
                        subtitle: "累计收入",
                        icon: "wallet.pass",
                        color: Color.green.opacity(0.12)
                    )
                    OverviewCard(
                        title: "总支出",
                        value: totalExpense,
                        subtitle: "累计支出",
                        icon: "creditcard",
                        color: Color.red.opacity(0.12)
                    )
                }

                // MARK: Chart Section
                ChartSection(dataPoints: dailyDataPoints)

                // MARK: Recent Transactions
                recentTransactionsSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Recent Transactions Section

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最近账单")
                .font(.system(size: 17, weight: .semibold))

            if allBills.isEmpty {
                Text("暂无数据")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 2) {
                    ForEach(allBills.prefix(8)) { bill in
                        BillRow(bill: bill)
                            .background(Color.clear)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).cornerRadius(10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Subviews (file-level, reusable)

struct StatCard: View {
    let title: String
    var value: Double?
    var count: Int?
    let icon: String
    let color: Color

    private var displayValue: String {
        if let c = count {
            return "\(c)"
        } else if let v = value {
            return formatCurrency(v)
        }
        return "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)

            Text(displayValue)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

private struct OverviewCard: View {
    let title: String
    let value: Double
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.primary)
                Spacer()
            }

            Text(formatCurrency(value))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(22)
        .background(color)
        .cornerRadius(16)
    }
}

private struct ChartSection: View {
    let dataPoints: [DashboardView.DayDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("近 30 天趋势")
                .font(.system(size: 17, weight: .semibold))

            if dataPoints.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
                Text("暂无数据")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(dataPoints) { point in
                        BarMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("支出", point.expense)
                        )
                        .foregroundStyle(Color.red.gradient)
                        .cornerRadius(3, style: .continuous)

                        BarMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("收入", point.income)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .cornerRadius(3, style: .continuous)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(0.15))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.caption2)
                    }
                }
                .chartPlotStyle { plot in
                    plot.background(Color(nsColor: .controlBackgroundColor).cornerRadius(12))
                }
                .frame(height: 220)
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

private struct BillRow: View {
    let bill: Bill

    private var isExpense: Bool { bill.type == "expenditure" || bill.type == "transfer" }
    private var amountText: String {
        let prefix = isExpense ? "-" : "+"
        return "\(prefix)\(formatCurrency(bill.amount?.doubleValue ?? 0))"
    }

    private var dateText: String {
        guard let date = bill.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isExpense ? Color.red.opacity(0.08) : Color.green.opacity(0.08))
                    .frame(width: 36, height: 36)

                Image(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isExpense ? .red : .green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.category ?? "未分类")
                    .font(.system(size: 13, weight: .medium))
                if let note = bill.note, !note.isEmpty, note != "无备注" {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isExpense ? .red : .green)
                Text(dateText)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var categoryIcon: String {
        guard let cat = bill.category else { return "questionmark" }
        if isExpense {
            return ExpenditureCategory.allCases.first(where: { $0.rawValue == cat })?.icon ?? "questionmark"
        }
        return IncomeCategory.allCases.first(where: { $0.rawValue == cat })?.icon ?? "questionmark"
    }
}

// MARK: - Helpers (file-level, reusable)

func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "¥"
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter.string(from: NSNumber(value: value)) ?? "¥\(value)"
}
