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

    /// 松手后仍用于绘制浮层淡出（selectedDate 变 nil 时不立刻移除视图）
    @State private var lastSelectedDate: Date?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

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

    /// R2/R3/R4：跨 0 的对称刻度模型（收入向上、支出向下，0 始终是刻度）
    private var yAxisModel: ChartAxisModel {
        ChartAxisSupport.bidirectionalAxis(
            minValue: visiblePoints.map(\.expenseBarValue).min() ?? 0,
            maxValue: visiblePoints.map(\.income).max() ?? 0
        )
    }

    /// R6：中文 / 日文轴标签用「万」，英文用「k」
    private var usesTenThousandUnit: Bool {
        ChartAxisSupport.usesTenThousandUnit(for: locale)
    }

    /// 系列分组标签（本地化后同一系列在各数据点上取值一致，分组稳定）
    private var kindTagIncome: String { L10n.string("tendency.net.income") }
    private var kindTagExpense: String { L10n.string("tendency.net.expense") }

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
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text("tendency.last_year")
                    .font(AppTypography.tiny)
                    .foregroundStyle(.secondary)
            }

            // R7：标题下的结论副标题（区间 + 净额，取自现有可见区间数值）
            Text(subtitleText)
                .font(AppTypography.tiny)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
                     value: "¥\(formatAmount(income))", accent: ChartSeriesStyle.income(for: colorScheme))
            statPill(icon: "arrow.up.circle.fill", titleKey: "tendency.net.expense",
                     value: "¥\(formatAmount(expense))", accent: ChartSeriesStyle.expense(for: colorScheme))
            statPill(icon: "equal.circle.fill", titleKey: "tendency.net.net",
                     value: "¥\(formatAmount(net))",
                     accent: net >= 0 ? ChartSeriesStyle.income(for: colorScheme) : ChartSeriesStyle.expense(for: colorScheme))
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
                    x: .value(L10n.string("tendency.a11y.date"), point.date, unit: isMonthly ? .month : .day),
                    y: .value(L10n.string("tendency.a11y.amount"), point.income)
                )
                .foregroundStyle(ChartSeriesStyle.income(for: colorScheme).gradient)
                .position(by: .value(L10n.string("tendency.net.income"), kindTagIncome))
                .cornerRadius(2)

                BarMark(
                    x: .value(L10n.string("tendency.a11y.date"), point.date, unit: isMonthly ? .month : .day),
                    y: .value(L10n.string("tendency.a11y.amount"), point.expenseBarValue)
                )
                .foregroundStyle(ChartSeriesStyle.expense(for: colorScheme).gradient)
                .position(by: .value(L10n.string("tendency.net.expense"), kindTagExpense))
                .cornerRadius(2)

                // R14：开启「不以颜色为唯一区分手段」时，用形状再次区分两个系列
                if differentiateWithoutColor {
                    PointMark(
                        x: .value(L10n.string("tendency.a11y.date"), point.date, unit: isMonthly ? .month : .day),
                        y: .value(L10n.string("tendency.a11y.amount"), point.income)
                    )
                    .symbol(.circle)
                    .symbolSize(22)
                    .foregroundStyle(ChartSeriesStyle.income(for: colorScheme))

                    PointMark(
                        x: .value(L10n.string("tendency.a11y.date"), point.date, unit: isMonthly ? .month : .day),
                        y: .value(L10n.string("tendency.a11y.amount"), point.expenseBarValue)
                    )
                    .symbol(.square)
                    .symbolSize(22)
                    .foregroundStyle(ChartSeriesStyle.expense(for: colorScheme))
                }
            }

            RuleMark(y: .value(L10n.string("tendency.a11y.zero"), 0))
                .foregroundStyle(Color.secondary.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yAxisModel.domain)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisLabel(for: date))
                            .font(AppTypography.tiny)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: yAxisModel.ticks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        // 零轴下侧是支出，刻度显示绝对值更易读（R6：紧凑、不带单位）
                        Text(ChartAxisSupport.compactAmount(abs(amount), usesTenThousandUnit: usesTenThousandUnit))
                            .font(AppTypography.tiny)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            scrubOverlay(proxy: proxy)
        }
        .chartPlotStyle { plot in
            plot.background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.secondary.opacity(0.05))
            )
        }
        // 原生 scrub：按下即选、拖动吸附最近数据点、松手把绑定置空
        .chartXSelection(value: $selectedDate)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("tendency.net.title"))
        .accessibilityValue(accessibilityValueText)
        .accessibilityHint(L10n.string("tendency.a11y.hint"))
        .accessibilityChartDescriptor(ChartDescriptorRepresentable { chartDescriptor })
        .appAnimation(AppMotion.quick, value: selectedDate)
        .onChange(of: selectedDate) { oldValue, newValue in
            handleSelectionChange(from: oldValue, to: newValue)
        }
        .task(id: edgeHold) {
            await runEdgeAutoScroll()
        }
    }

    // MARK: - Scrub 绘制（指示线 + 浮层）

    @ViewBuilder
    private func scrubOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            if let frame = proxy.plotFrame {
                let plotRect = geometry[frame]
                // 松手后仍用 lastSelectedDate 画最后一帧，配合 AppMotion.quick 淡出
                if let date = selectedDate ?? lastSelectedDate,
                   let x = proxy.position(forX: date) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 1, height: plotRect.height)
                        .position(x: plotRect.minX + x, y: plotRect.midY)

                    ScrubCallout(plotRect: plotRect, anchorX: x, isVisible: selectedDate != nil) {
                        calloutContent(for: date)
                    }
                    .accessibilityHidden(true)
                }
            }
        }
    }

    @ViewBuilder
    private func calloutContent(for date: Date) -> some View {
        let point = selectedPoint ?? visiblePoints.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
        VStack(alignment: .leading, spacing: 2) {
            Text(calloutDateText(for: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let point {
                calloutRow(titleKey: "tendency.net.income", value: point.income, color: .green)
                calloutRow(titleKey: "tendency.net.expense", value: point.expense, color: .red)
                calloutRow(titleKey: "tendency.net.net", value: point.net, color: point.net >= 0 ? .green : .red)
            }
        }
    }

    private func calloutRow(titleKey: String, value: Double, color: Color) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(LocalizedStringKey(titleKey))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("¥\(formatAmount(value))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func calloutDateText(for date: Date) -> String {
        isMonthly
            ? date.formatted(.dateTime.year().month())
            : date.formatted(.dateTime.month().day())
    }

    // MARK: - 选中变化：触觉门控 + 贴边判定

    private func handleSelectionChange(from oldValue: Date?, to newValue: Date?) {
        let dates = visiblePoints.map(\.date)
        let oldIndex = oldValue.flatMap { ScrubSelection.index(of: $0, in: dates) }
        let newIndex = newValue.flatMap { ScrubSelection.index(of: $0, in: dates) }
        if ScrubSelection.shouldTick(from: oldIndex, to: newIndex) {
            HapticManager.shared.selectionChanged()
        }
        if let newValue { lastSelectedDate = newValue }
    }

    /// 贴边状态：-1 贴左、1 贴右、0 不贴边
    private var edgeHold: Int {
        guard let selectedDate, !visiblePoints.isEmpty else { return 0 }
        let dates = visiblePoints.map(\.date)
        guard let index = ScrubSelection.index(of: selectedDate, in: dates) else { return 0 }
        return ScrubSelection.edgeHold(index: index, count: dates.count)
    }

    /// 贴边继续按住时的窗口步进：原生选择手势不提供连续拖动增量，这里用 200ms 步进近似
    private func runEdgeAutoScroll() async {
        guard edgeHold != 0 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            let direction = edgeHold
            guard direction != 0 else { return }
            guard stepWindow(direction: direction) else { return }
        }
    }

    /// 推进一档窗口（按月卡 = 1 个月，按天卡 = 1 天），返回是否真的移动
    private func stepWindow(direction: Int) -> Bool {
        guard let first = points.first?.date, let last = points.last?.date else { return false }
        let calendar = Calendar.current
        let proposed: Date
        if isMonthly {
            proposed = calendar.date(byAdding: .month, value: direction, to: monthStart(scrollPosition)) ?? scrollPosition
        } else {
            proposed = calendar.date(byAdding: .day, value: direction, to: scrollPosition.startOfDay) ?? scrollPosition
        }
        let today = Date().startOfDay
        let upper = min(today, last)
        let clamped: Date
        if proposed < first { clamped = first }
        else if proposed > upper { clamped = upper }
        else { clamped = proposed }
        guard clamped != scrollPosition else { return false }
        scrollPosition = clamped
        // 选中态跟随新的窗口边缘，保持「贴边继续扫读」的体感
        selectedDate = clamped
        return true
    }

    // MARK: - 辅助

    /// R7：副标题（区间 + 净额），只组合现有可见区间数值
    private var subtitleText: String {
        guard let first = visiblePoints.first?.date, let last = visiblePoints.last?.date else { return "" }
        let income = visiblePoints.reduce(0) { $0 + $1.income }
        let expense = visiblePoints.reduce(0) { $0 + $1.expense }
        let range = ChartSummary.rangeText(from: first, to: last, monthly: isMonthly)
        return ChartSummary.netSubtitle(rangeText: range, net: income - expense)
    }

    /// R18：图表描述符（收入 / 支出两个系列 + 摘要 + Audio Graph）
    private var chartDescriptor: AXChartDescriptor {
        ChartAccessibility.netDescriptor(
            title: L10n.string("tendency.net.title"),
            summary: accessibilityValueText,
            points: visiblePoints.map { (date: $0.date, income: $0.income, expense: $0.expense) }
        )
    }

    private var accessibilityValueText: String {
        guard let point = selectedPoint else {
            let income = visiblePoints.reduce(0) { $0 + $1.income }
            let expense = visiblePoints.reduce(0) { $0 + $1.expense }
            return String(format: L10n.string("tendency.net.a11y.summary"),
                          formatAmount(income), formatAmount(expense), formatAmount(income - expense))
        }
        return String(format: L10n.string("tendency.net.a11y.selected"),
                      calloutDateText(for: point.date),
                      formatAmount(point.income), formatAmount(point.expense), formatAmount(point.net))
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
