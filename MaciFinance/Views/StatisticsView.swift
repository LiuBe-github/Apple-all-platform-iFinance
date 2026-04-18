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

    enum Period: String, CaseIterable, Identifiable {
        case week, month, year
        var id: String { rawValue }
        var title: String {
            switch self {
            case .week: return "本周"
            case .month: return "本月"
            case .year: return "本年"
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
        let name: String
        let amount: Double
        let count: Int
        let icon: String
    }

    private var expenseByCategory: [CategoryStat] {
        var dict: [String: (Double, Int)] = [:]
        for bill in periodBills where bill.type == "expenditure" {
            let cat = bill.category ?? "其他"
            dict[cat, default: (0, 0)].0 += bill.amount?.doubleValue ?? 0
            dict[cat, default: (0, 0)].1 += 1
        }
        return dict.map { key, val in
            let expCat = ExpenditureCategory.allCases.first(where: { $0.rawValue == key })
            return CategoryStat(name: key, amount: val.0, count: val.1, icon: expCat?.icon ?? "tag.fill")
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
                Picker("时间范围", selection: $selectedPeriod) {
                    ForEach(Period.allCases) { p in Text(p.title).tag(p) }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                // Summary cards
                HStack(spacing: 16) {
                    StatCard(title: "总收入", value: totalIncome, icon: "arrow.up.circle.fill", color: .green)
                    StatCard(title: "总支出", value: totalExpense, icon: "arrow.down.circle.fill", color: .red)
                    StatCard(title: "结余", value: totalIncome - totalExpense, icon: "equal.circle.fill", color: totalIncome >= totalExpense ? .blue : .orange)
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
            Text("收支趋势")
                .font(.system(size: 17, weight: .semibold))

            if dailyPoints.isEmpty || dailyPoints.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
                Text("暂无数据")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
            } else {
                Chart {
                    ForEach(dailyPoints) { point in
                        AreaMark(
                            x: .value("日期", point.date),
                            y: .value("支出", point.expense)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.red.opacity(0.15).gradient)

                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("支出", point.expense)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .foregroundStyle(.red)

                        AreaMark(
                            x: .value("日期", point.date),
                            y: .value("收入", point.income)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.green.opacity(0.15).gradient)

                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("收入", point.income)
                        )
                        .interpolationMethod(.catmullRom)
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
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }

    // MARK: Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出分类")
                .font(.system(size: 17, weight: .semibold))

            if expenseByCategory.isEmpty {
                Text("暂无支出数据")
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

                Text(stat.name)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Text(formatCurrency(stat.amount))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))

                Text("\(stat.count)笔")
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
