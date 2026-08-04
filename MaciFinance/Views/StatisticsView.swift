//
//  StatisticsView.swift
//  MaciFinance
//

import SwiftUI
import CoreData
import Charts

struct StatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: true)]
    ) private var allBills: FetchedResults<Bill>

    @State private var selectedPeriod: Period = .month
    @State private var selectedChartType: ChartType = .line

    enum Period: String, CaseIterable, Identifiable {
        case week, month, year
        var id: String { rawValue }
        var title: String {
            switch self {
            case .week: return L10n.string("mac.stat.period_week")
            case .month: return L10n.string("mac.stat.period_month")
            case .year: return L10n.string("mac.stat.period_year")
            }
        }

        func range() -> (Date, Date) {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .week:
                let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
                let end = cal.date(byAdding: .day, value: 7, to: start)!
                return (start, min(end, now))
            case .month:
                guard let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { return (now, now) }
                return (start, now)
            case .year:
                guard let start = cal.date(from: cal.dateComponents([.year], from: now)) else { return (now, now) }
                return (start, now)
            }
        }
    }

    enum ChartType: String, CaseIterable, Identifiable {
        case line, bar
        var id: String { rawValue }
        var title: String {
            switch self {
            case .line: return L10n.string("mac.stat.chart_line")
            case .bar: return L10n.string("mac.stat.chart_bar")
            }
        }
        var icon: String {
            switch self {
            case .line: return "chart.line.uptrend.xyaxis"
            case .bar: return "chart.bar.fill"
            }
        }
    }

    // MARK: - Filtered data

    private var periodBills: [Bill] {
        let (start, end) = selectedPeriod.range()
        return allBills.filter {
            guard let date = $0.date else { return false }
            return date >= start && date <= end
        }
    }

    // MARK: - Totals

    private var totalExpense: Double {
        periodBills.filter { $0.type == "expenditure" }.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }
    private var totalIncome: Double {
        periodBills.filter { $0.type == "income" }.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }

    // MARK: - Category breakdown

    // MARK: - Category breakdown

    struct CategoryStat: Identifiable {
        let id = UUID()
        let name: String        // raw key (e.g. "cat.exp.food" or "uncategorized")
        let amount: Double
        let count: Int
        let icon: String
    }

    private var expenseByCategory: [CategoryStat] {
        var dict: [String: (Double, Int)] = [:]
        for bill in periodBills where bill.type == "expenditure" {
            let cat = bill.category ?? "uncategorized"
            dict[cat, default: (0, 0)].0 += bill.amount?.doubleValue ?? 0
            dict[cat, default: (0, 0)].1 += 1
        }
        return dict.map { key, val in
            let expCat = ExpenditureCategory.allCases.first(where: { $0.localizedKey == key || $0.rawValue == key })
            let localizedName = expCat?.localizedKey ?? "mac.bill.uncategorized"
            return CategoryStat(name: localizedName, amount: val.0, count: val.1, icon: expCat?.icon ?? "tag.fill")
        }
        .sorted { $0.amount > $1.amount }
    }

    // MARK: - Daily data for line chart

    private struct DayPoint: Identifiable {
        let id = UUID()
        let date: Date
        let expense: Double
        let income: Double
    }

    private var dailyPoints: [DayPoint] {
        let (start, end) = selectedPeriod.range()
        let cal = Calendar.current
        var points: [DayPoint] = []

        var current = start
        while current <= end {
            let dayEnd = cal.date(byAdding: .day, value: 1, to: current)!
            let dayBills = allBills.filter {
                guard let d = $0.date else { return false }
                return d >= current && d < dayEnd
            }
            let expense = dayBills.filter { $0.type == "expenditure" }.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
            let income = dayBills.filter { $0.type == "income" }.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
            points.append(DayPoint(date: current, expense: expense, income: income))

            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return points
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Period picker
                Picker(L10n.string("bill.time_range"), selection: $selectedPeriod) {
                    ForEach(Period.allCases) { p in Text(p.title).tag(p) }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                // Summary cards
                HStack(spacing: 16) {
                    StatCard(title: L10n.string("mac.stat.total_income"), value: totalIncome, icon: "arrow.up.circle.fill", color: .green)
                    StatCard(title: L10n.string("mac.stat.total_expense"), value: totalExpense, icon: "arrow.down.circle.fill", color: .red)
                    StatCard(title: L10n.string("mac.stat.balance"), value: totalIncome - totalExpense, icon: "equal.circle.fill", color: totalIncome >= totalExpense ? .blue : .orange)
                }

                // Line chart
                trendChartSection

                // Category breakdown
                categoryBreakdownSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Trend Chart Section

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.string("mac.stat.income_trend"))
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Picker("", selection: $selectedChartType) {
                    ForEach(ChartType.allCases) { type in
                        Label(type.title, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            if dailyPoints.isEmpty || dailyPoints.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
                Text(L10n.string("mac.stat.no_data"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
            } else {
                chartContent
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }

    @ViewBuilder
    private var chartContent: some View {
        switch selectedChartType {
        case .line:
            lineChart
        case .bar:
            barChart
        }
    }

    // MARK: Line Chart (纯折线，无曲线)

    private var lineChart: some View {
        Chart {
            ForEach(dailyPoints) { point in
                LineMark(
                    x: .value(L10n.string("mac.stat.date"), point.date),
                    y: .value(L10n.string("mac.stat.expense"), point.expense)
                )
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .foregroundStyle(.red)

                LineMark(
                    x: .value(L10n.string("mac.stat.date"), point.date),
                    y: .value(L10n.string("mac.stat.income"), point.income)
                )
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .foregroundStyle(.green)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel().font(.caption2)
                AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
            }
        }
        .chartPlotStyle { plot in
            plot.background(Color(nsColor: .controlBackgroundColor).cornerRadius(14))
        }
        .frame(height: 260)
    }

    // MARK: Bar Chart

    private var barChart: some View {
        Chart {
            ForEach(dailyPoints) { point in
                BarMark(
                    x: .value(L10n.string("mac.stat.date"), point.date),
                    y: .value(L10n.string("mac.stat.expense"), point.expense)
                )
                .foregroundStyle(.red.opacity(0.8))
                .position(by: .value(L10n.string("mac.bill.filter_type"), L10n.string("mac.stat.expense")))

                BarMark(
                    x: .value(L10n.string("mac.stat.date"), point.date),
                    y: .value(L10n.string("mac.stat.income"), point.income)
                )
                .foregroundStyle(.green.opacity(0.8))
                .position(by: .value(L10n.string("mac.bill.filter_type"), L10n.string("mac.stat.income")))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel().font(.caption2)
                AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
            }
        }
        .chartForegroundStyleScale([
            L10n.string("mac.stat.expense"): Color.red,
            L10n.string("mac.stat.income"): Color.green
        ])
        .chartLegend(position: .top)
        .chartPlotStyle { plot in
            plot.background(Color(nsColor: .controlBackgroundColor).cornerRadius(14))
        }
        .frame(height: 260)
    }

    // MARK: Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("mac.stat.expense_category"))
                .font(.system(size: 17, weight: .semibold))

            if expenseByCategory.isEmpty {
                Text(L10n.string("mac.stat.no_expense_data"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 10) {
                    ForEach(expenseByCategory.prefix(8)) { stat in
                        CategoryRow(stat: stat, maxAmount: expenseByCategory[0].amount)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

// MARK: - Subviews

private struct CategoryRow: View {
    let stat: StatisticsView.CategoryStat
    let maxAmount: Double

    private var barWidth: Double {
        guard maxAmount > 0 else { return 0 }
        return min(stat.amount / maxAmount * 1.0, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: stat.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)

                Text(L10n.string(stat.name))
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Text(formatCurrency(stat.amount))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))

                Text(String(format: L10n.string("mac.stat.count_bills"), stat.count))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.red.gradient)
                    .frame(width: geo.size.width * barWidth, height: 6)
            }
            .frame(height: 6)
        }
    }
}
