//
//  NetTrendCard.swift
//  iFinance
//
//  趋势页「总收支」双向柱状图：收入向上（绿）、支出向下（红），零轴居中。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI
import Charts

// MARK: - 数据模型

/// 单个时间桶的收入 / 支出
struct NetTrendPoint: Identifiable, Equatable {
    let date: Date
    let income: Double
    let expense: Double

    var net: Double { income - expense }
    /// 支出柱的绘制值：零轴为界向下（收入柱用正的 income）
    var expenseBarValue: Double { -expense }
    /// 稳定 id：图表重绘时避免全量 diff
    var id: Date { date }
}

// MARK: - 聚合（纯函数，便于单测）

enum NetTrendBuilder {

    /// 生成完整序列：月档按天（覆盖最近 13 个月）、6 个月 / 年档按月（覆盖最近 24 个月）
    /// - Parameter entries: (日期, 类型, 金额)，类型为 `"income"` / `"expenditure"`，转账不计入
    static func series(
        entries: [(date: Date, type: String, amount: Double)],
        spanDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [NetTrendPoint] {
        let daily = spanDays < 180
        var buckets: [Date: (income: Double, expense: Double)] = [:]

        for entry in entries {
            guard let kind = kind(of: entry.type) else { continue }
            let bucketDate: Date
            if daily {
                bucketDate = calendar.startOfDay(for: entry.date)
            } else {
                bucketDate = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: entry.date)
                ) ?? entry.date
            }
            var bucket = buckets[bucketDate] ?? (0, 0)
            if kind == .income {
                bucket.income += entry.amount
            } else {
                bucket.expense += entry.amount
            }
            buckets[bucketDate] = bucket
        }

        if daily {
            let today = calendar.startOfDay(for: now)
            let lookbackDays = 395
            return (0..<lookbackDays).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: -(lookbackDays - 1 - offset), to: today) else { return nil }
                let bucket = buckets[day] ?? (0, 0)
                return NetTrendPoint(date: day, income: bucket.income, expense: bucket.expense)
            }
        } else {
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let lookbackMonths = 25
            return (0..<lookbackMonths).compactMap { offset in
                guard let month = calendar.date(byAdding: .month, value: -(lookbackMonths - 1 - offset), to: currentMonth) else { return nil }
                let bucket = buckets[month] ?? (0, 0)
                return NetTrendPoint(date: month, income: bucket.income, expense: bucket.expense)
            }
        }
    }

    private enum Kind {
        case income
        case expense
    }

    private static func kind(of type: String) -> Kind? {
        switch type {
        case "income": return .income
        case "expenditure": return .expense
        default: return nil
        }
    }
}

// MARK: - 卡片

struct NetTrendCard: View {
    /// 完整序列（由 `NetTrendBuilder.series` 生成）
    let points: [NetTrendPoint]
    @Binding var span: SpanOption
    @Binding var scrollPosition: Date
    @Binding var selectedDate: Date?

    @State private var dragMode: DragMode = .none
    @State private var dragStartScroll: Date?

    private enum DragMode {
        case none
        case select
        case scroll
    }

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.locale = .autoupdatingCurrent
        return f
    }()

    private var isMonthly: Bool { span.days >= 180 }

    // MARK: - 可见窗口

    private var visiblePoints: [NetTrendPoint] {
        guard !points.isEmpty else { return [] }
        let end = clampedEndDate
        if isMonthly {
            let months = span.days >= 365 ? 12 : 6
            let endMonth = monthStart(end)
            guard let startMonth = Calendar.current.date(byAdding: .month, value: -(months - 1), to: endMonth) else { return points }
            return points.filter { $0.date >= startMonth && $0.date <= endMonth }
        } else {
            let calendar = Calendar.current
            let endDay = calendar.startOfDay(for: end)
            guard let startDay = calendar.date(byAdding: .day, value: -(span.days - 1), to: endDay) else { return points }
            return points.filter { $0.date >= startDay && $0.date <= endDay }
        }
    }

    private var clampedEndDate: Date {
        let today = Date().startOfDay
        let earliest = points.first?.date ?? today
        let latest = min(today, points.last?.date ?? today)
        let target = scrollPosition.startOfDay
        if target < earliest { return earliest }
        if target > latest { return latest }
        return target
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = visiblePoints.first?.date, let last = visiblePoints.last?.date, first <= last else {
            let now = Date()
            return now...now.addingTimeInterval(86_400)
        }
        let padding: TimeInterval = isMonthly ? 86_400 * 15 : 86_400 * 0.5
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }

    private var yDomain: ClosedRange<Double> {
        let maxIncome = visiblePoints.map(\.income).max() ?? 0
        let maxExpense = visiblePoints.map(\.expense).max() ?? 0
        if maxIncome == 0 && maxExpense == 0 { return -1...1 }
        return (-max(maxExpense, 0.0001))...max(maxIncome, 0.0001)
    }

    private var selectedPoint: NetTrendPoint? {
        guard let selectedDate else { return nil }
        return visiblePoints.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    // MARK: - 视图

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("tendency.net.title")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("tendency.last_year")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: $span) {
                ForEach(SpanOption.netOptions) { item in
                    Text(LocalizedStringKey(item.titleKey)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: span) { _, _ in
                HapticManager.shared.selectionChanged()
                scrollPosition = Date().startOfDay
                selectedDate = nil
            }

            metricsView
            hintOrSelection

            if visiblePoints.allSatisfy({ $0.income == 0 && $0.expense == 0 }) {
                emptyPlaceholder
            } else {
                chart
                    .frame(height: TendencyConstants.chartHeight)
            }
        }
        .padding(TendencyConstants.cardPadding)
        .appGlassCard(cornerRadius: TendencyConstants.cardCornerRadius)
    }

    // MARK: - 子视图

    private var metricsView: some View {
        let income = visiblePoints.reduce(0) { $0 + $1.income }
        let expense = visiblePoints.reduce(0) { $0 + $1.expense }
        let net = income - expense
        return HStack(spacing: AppSpacing.md) {
            statPill(icon: "arrow.down.circle.fill", titleKey: "tendency.net.income",
                     value: "¥\(formatAmount(income))", accent: .green)
            statPill(icon: "arrow.up.circle.fill", titleKey: "tendency.net.expense",
                     value: "¥\(formatAmount(expense))", accent: .red)
            statPill(icon: "equal.circle.fill", titleKey: "tendency.net.net",
                     value: "¥\(formatAmount(net))", accent: net >= 0 ? .green : .red)
        }
    }

    private func statPill(icon: String, titleKey: LocalizedStringKey, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                Text(titleKey)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: TendencyConstants.statPillCornerRadius, style: .continuous)
                .fill(accent.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: TendencyConstants.statPillCornerRadius, style: .continuous)
                        .strokeBorder(accent.opacity(0.18), lineWidth: 0.8)
                )
        }
    }

    @ViewBuilder
    private var hintOrSelection: some View {
        if let point = selectedPoint {
            Text(selectionText(for: point))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("tendency.drag_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
                .frame(height: TendencyConstants.chartHeight)

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary.opacity(0.6))
                Text("tendency.no_data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: TendencyConstants.chartHeight)
    }

    private var chart: some View {
        Chart {
            ForEach(visiblePoints) { point in
                BarMark(
                    x: .value("date", point.date, unit: isMonthly ? .month : .day),
                    y: .value("amount", point.income)
                )
                .foregroundStyle(Color.green.gradient)
                .position(by: .value("kind", "income"))
                .cornerRadius(2)
                .opacity(barOpacity(for: point))

                BarMark(
                    x: .value("date", point.date, unit: isMonthly ? .month : .day),
                    y: .value("amount", point.expenseBarValue)
                )
                .foregroundStyle(Color.red.gradient)
                .position(by: .value("kind", "expense"))
                .cornerRadius(2)
                .opacity(barOpacity(for: point))
            }

            RuleMark(y: .value("zero", 0))
                .foregroundStyle(Color.secondary.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.22))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisLabel(for: date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                    .foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        // 零轴下侧是支出，刻度显示绝对值更易读
                        Text(formatAmount(abs(amount))).font(.caption2)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            chartGestureOverlay(proxy: proxy)
        }
        .chartPlotStyle { plot in
            plot.background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.secondary.opacity(0.05))
            )
        }
        .padding(.horizontal, TendencyConstants.chartHorizontalPadding)
        .appAnimation(AppMotion.standard, value: selectedDate)
    }

    // MARK: - 手势（按柱子选中 / 空白处横向滚动）

    @ViewBuilder
    private func chartGestureOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let frame = proxy.plotFrame else { return }
                            let plotOrigin = geometry[frame].origin
                            let plotSize = geometry[frame].size
                            guard plotSize.width > 0, plotSize.height > 0 else { return }
                            let x = value.location.x - plotOrigin.x
                            let y = value.location.y - plotOrigin.y

                            if dragMode == .none {
                                dragMode = resolveDragMode(x: x, y: y, plotSize: plotSize, proxy: proxy)
                                dragStartScroll = scrollPosition
                            }

                            switch dragMode {
                            case .select:
                                guard x >= 0, x <= plotSize.width, y >= 0, y <= plotSize.height else { return }
                                updateSelection(at: x, proxy: proxy)
                            case .scroll:
                                guard let base = dragStartScroll else { return }
                                scrollWindow(from: base, translation: value.translation.width, plotWidth: plotSize.width)
                            case .none:
                                break
                            }
                        }
                        .onEnded { _ in
                            dragMode = .none
                            dragStartScroll = nil
                        }
                )
        }
    }

    private func resolveDragMode(x: CGFloat, y: CGFloat, plotSize: CGSize, proxy: ChartProxy) -> DragMode {
        let insideVertically = y >= 0 && y <= plotSize.height
        if insideVertically, isNearDataPoint(x: x, proxy: proxy) {
            return .select
        }
        return .scroll
    }

    private func isNearDataPoint(x: CGFloat, proxy: ChartProxy) -> Bool {
        guard let date: Date = proxy.value(atX: x, as: Date.self),
              let nearest = visiblePoints.min(by: {
                  abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
              }),
              let px = proxy.position(forX: nearest.date) else {
            return false
        }
        return abs(px - x) <= TendencyConstants.touchDetectionRadius
    }

    private func updateSelection(at x: CGFloat, proxy: ChartProxy) {
        guard let date: Date = proxy.value(atX: x, as: Date.self),
              let nearest = visiblePoints.min(by: {
                  abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
              }),
              let px = proxy.position(forX: nearest.date) else {
            return
        }
        let dx = px - x
        if dx * dx <= TendencyConstants.touchDetectionRadius * TendencyConstants.touchDetectionRadius {
            selectedDate = nearest.date
        }
    }

    private func scrollWindow(from base: Date, translation: CGFloat, plotWidth: CGFloat) {
        guard plotWidth > 0, let first = points.first?.date, let last = points.last?.date else { return }
        let calendar = Calendar.current
        let shiftRatio = -Double(translation / plotWidth)
        let proposed: Date
        if isMonthly {
            let monthsShift = Int((shiftRatio * Double(span.days >= 365 ? 12 : 6)).rounded())
            proposed = calendar.date(byAdding: .month, value: monthsShift, to: monthStart(base)) ?? base
        } else {
            let daysShift = Int((shiftRatio * Double(span.days)).rounded())
            proposed = calendar.date(byAdding: .day, value: daysShift, to: base.startOfDay) ?? base
        }
        let today = Date().startOfDay
        let upper = min(today, last)
        if proposed < first { scrollPosition = first }
        else if proposed > upper { scrollPosition = upper }
        else { scrollPosition = proposed }
    }

    // MARK: - 辅助

    private func barOpacity(for point: NetTrendPoint) -> Double {
        guard let selectedPoint else { return 1 }
        return selectedPoint.date == point.date ? 1 : 0.35
    }

    private func monthStart(_ date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private func formatAmount(_ value: Double) -> String {
        Self.amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func axisLabel(for date: Date) -> String {
        if isMonthly {
            let calendar = Calendar.current
            return "\(calendar.component(.month, from: date))月"
        }
        let calendar = Calendar.current
        return "\(calendar.component(.month, from: date))/\(calendar.component(.day, from: date))"
    }

    private func selectionText(for point: NetTrendPoint) -> String {
        let income = L10n.string("tendency.net.income")
        let expense = L10n.string("tendency.net.expense")
        let net = L10n.string("tendency.net.net")
        return "\(income) ¥\(formatAmount(point.income)) · \(expense) ¥\(formatAmount(point.expense)) · \(net) ¥\(formatAmount(point.net))"
    }
}
