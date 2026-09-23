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
        predicate: NSPredicate(format: "createdBy == %@", PersistenceController.currentUserIdentifier),
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
            predicate: NSPredicate(format: "date >= %@ AND date < %@ AND createdBy == %@", startOfDay as NSDate, endOfDay as NSDate, PersistenceController.currentUserIdentifier)
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
                    StatCard(title: L10n.string("mac.dashboard.today_expense"), value: todayExpense, icon: "arrow.down.circle.fill", color: .red)
                    StatCard(title: L10n.string("mac.dashboard.today_income"), value: todayIncome, icon: "arrow.up.circle.fill", color: .green)
                    StatCard(title: L10n.string("mac.dashboard.total_balance"), value: balance, icon: "yensign.circle.fill", color: .blue)
                    StatCard(title: L10n.string("mac.dashboard.bill_count"), count: billCount, icon: "list.bullet", color: .orange)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: billCount)

                // MARK: Overview Section
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    OverviewCard(
                        title: L10n.string("mac.dashboard.total_income"),
                        value: totalIncome,
                        subtitle: L10n.string("mac.dashboard.total_income_cumulative"),
                        icon: "arrow.down.left.circle.fill",
                        color: Color.green.opacity(0.12),
                        accent: .green
                    )
                    OverviewCard(
                        title: L10n.string("mac.dashboard.total_expense"),
                        value: totalExpense,
                        subtitle: L10n.string("mac.dashboard.total_expense_cumulative"),
                        icon: "arrow.up.right.circle.fill",
                        color: Color.red.opacity(0.12),
                        accent: .red
                    )
                }

                // MARK: Chart Section
                ChartSection(dataPoints: dailyDataPoints)

                // MARK: Recent Transactions
                recentTransactionsSection
            }
            .padding(24)
        }
    }

    // MARK: Recent Transactions Section

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("mac.dashboard.recent_bills"))
                .font(.system(size: 17, weight: .semibold))

            if allBills.isEmpty {
                Text(L10n.string("mac.stat.no_data"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(allBills.prefix(8).enumerated()), id: \.element.objectID) { index, bill in
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
        .macCard(cornerRadius: 16)
    }
}

// MARK: - Subviews (file-level, reusable)

struct StatCard: View {
    let title: String
    var value: Double?
    var count: Int?
    let icon: String
    let color: Color

    @State private var isHovering = false

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
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.22), color.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(color.opacity(0.25), lineWidth: 0.8)
                            )
                    )
                Spacer()
            }

            Text(displayValue)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .appNumericTransition(value: value ?? Double(count ?? 0))

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .macCard(cornerRadius: 14)
        .macHoverLift(isHovering)
        .onHover { isHovering = $0 }
    }
}

private struct OverviewCard: View {
    let title: String
    let value: Double
    let subtitle: String
    let icon: String
    let color: Color
    let accent: Color

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(accent)
                Spacer()
            }

            Text(formatCurrency(value))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .appNumericTransition(value: value)

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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(0.2), lineWidth: 0.8)
        )
        .macHoverLift(isHovering)
        .onHover { isHovering = $0 }
    }
}

private struct ChartSection: View {
    let dataPoints: [DashboardView.DayDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("mac.dashboard.30day_trend"))
                .font(.system(size: 17, weight: .semibold))

            if dataPoints.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
                Text(L10n.string("mac.stat.no_data"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(dataPoints) { point in
                        BarMark(
                            x: .value(L10n.string("mac.stat.date"), point.date, unit: .day),
                            y: .value(L10n.string("mac.stat.expense"), point.expense)
                        )
                        .foregroundStyle(Color.red.gradient)
                        .cornerRadius(3, style: .continuous)
                        .position(by: .value(L10n.string("mac.bill.filter_type"), L10n.string("mac.stat.expense")))

                        BarMark(
                            x: .value(L10n.string("mac.stat.date"), point.date, unit: .day),
                            y: .value(L10n.string("mac.stat.income"), point.income)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .cornerRadius(3, style: .continuous)
                        .position(by: .value(L10n.string("mac.bill.filter_type"), L10n.string("mac.stat.income")))
                    }
                }
                .chartForegroundStyleScale([
                    L10n.string("mac.stat.expense"): Color.red,
                    L10n.string("mac.stat.income"): Color.green
                ])
                .chartLegend(position: .top, alignment: .trailing)
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
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: dataPoints.count)
            }
        }
        .padding(20)
        .macCard(cornerRadius: 16)
    }
}

private struct BillRow: View {
    let bill: Bill

    @State private var isHovering = false

    private var isExpense: Bool { bill.type == "expenditure" || bill.type == "transfer" }
    private var amountText: String {
        let prefix = isExpense ? "-" : "+"
        return "\(prefix)\(formatCurrency(bill.amount?.doubleValue ?? 0))"
    }

    private var dateText: String {
        guard let date = bill.date else { return "" }
        let f = Date.FormatStyle(date: .numeric, time: .shortened)
        return date.formatted(f)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                (isExpense ? Color.red : Color.green).opacity(0.16),
                                (isExpense ? Color.red : Color.green).opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder((isExpense ? Color.red : Color.green).opacity(0.2), lineWidth: 0.8)
                    )

                Image(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isExpense ? .red : .green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.category ?? L10n.string("mac.bill.uncategorized"))
                    .font(.system(size: 13, weight: .medium))
                if let note = bill.note, !note.isEmpty, note != L10n.string("mac.bill.no_note") {
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
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
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
