//
//  TendencyChartView.swift
//  iFinance
//

import SwiftUI
import Charts

/// 趋势柱状图视图（原折线图已移除）。
/// 交互：Apple Health 式 scrub —— 原生 `chartXSelection` 负责「按下即选 / 拖动吸附 / 松手清空」，
/// 指示线与浮层由 `chartOverlay` 绘制（松手按 `AppMotion.quick` 淡出），
/// 贴边继续按住时按日历步长自动滚动时间窗口。日志见 `ScrubSupport.swift` 顶部说明。
struct TendencyChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    
    // MARK: - 数据
    
    let series: [DailyAmount]
    let accent: Color
    let visibleDays: Int
    let isHourly: Bool
    /// 完整数据范围（贴边自动滚动时用于夹取窗口位置）
    let scrollBounds: ClosedRange<Date>
    /// 图表无障碍标题的本地化 key（默认「趋势图」）
    let titleKey: String
    
    // MARK: - 交互状态
    
    @Binding var selectedDate: Date?
    @Binding var scrollPosition: Date

    /// 松手后仍用于绘制浮层淡出（selectedDate 变 nil 时不立刻移除视图）
    @State private var lastSelectedDate: Date?
    
    // MARK: - 格式化器（静态缓存）
    
    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .autoupdatingCurrent
        return f
    }()
    
    private static var dateFormatters: [String: DateFormatter] = [:]
    
    private static func dateFormatter(for pattern: String) -> DateFormatter {
        if let cached = dateFormatters[pattern] { return cached }
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = pattern
        dateFormatters[pattern] = f
        return f
    }
    
    // MARK: - 初始化
    
    init(
        series: [DailyAmount],
        accent: Color,
        visibleDays: Int,
        isHourly: Bool = false,
        scrollBounds: ClosedRange<Date>,
        titleKey: String = "tendency.a11y.chart",
        selectedDate: Binding<Date?>,
        scrollPosition: Binding<Date>
    ) {
        self.series = series
        self.accent = accent
        self.visibleDays = visibleDays
        self.isHourly = isHourly
        self.scrollBounds = scrollBounds
        self.titleKey = titleKey
        self._selectedDate = selectedDate
        self._scrollPosition = scrollPosition
    }
    
    // MARK: - 视图
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // 数据提示
            if let selected = selectedPoint {
                Text(selectedText(for: selected))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("tendency.drag_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 图表
            if series.isEmpty || series.allSatisfy({ $0.value == 0 }) {
                noDataPlaceholder
            } else {
                chartContent
                    .frame(height: TendencyConstants.chartHeight)
                    .appAnimation(AppMotion.standard, value: series.count)
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            handleSelectionChange(from: oldValue, to: newValue)
        }
        // 选中项贴住窗口边缘时自动滚动时间窗口（契约 4）
        .task(id: edgeHold) {
            await runEdgeAutoScroll()
        }
    }
    
    // MARK: - 私有计算属性
    
    private var selectedPoint: DailyAmount? {
        guard let date = selectedDate else { return nil }
        return series.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }
    
    private var viewDateRange: ClosedRange<Date> {
        let cal = Calendar.current
        let scrollPos = scrollPosition.startOfDay
        let viewStart = cal.date(byAdding: .day, value: -(visibleDays - 1), to: scrollPos) ?? scrollPos
        let viewEnd = cal.date(byAdding: .day, value: 1, to: scrollPos) ?? scrollPos
        return viewStart...viewEnd
    }
    
    private var visibleLength: TimeInterval {
        TimeInterval(visibleDays * 86_400)
    }

    /// R2/R3/R4：y 轴下界 0、上界随数据、刻度取整齐整数
    private var yAxisModel: ChartAxisModel {
        ChartAxisSupport.barAxis(maxValue: series.map(\.value).max() ?? 0)
    }

    /// R6：中文 / 日文轴标签用「万」，英文用「k」
    private var usesTenThousandUnit: Bool {
        ChartAxisSupport.usesTenThousandUnit(for: locale)
    }
    
    // MARK: - 子视图
    
    private var chartContent: some View {
        barChartView
    }
    
    @ViewBuilder
    private var noDataPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(accent.opacity(0.06))
                .frame(height: TendencyConstants.chartHeight)
                .blur(radius: 12)
            
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundStyle(accent.opacity(0.6))
                    .symbolEffect(.bounce, options: .speed(0.6).repeat(2))
                Text("tendency.no_data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: TendencyConstants.chartHeight)
    }
    
    // MARK: - 柱状图
    
    @ViewBuilder
    private var barChartView: some View {
        Chart {
            ForEach(series) { point in
                BarMark(
                    x: .value(L10n.string("tendency.a11y.date"), point.date),
                    y: .value(L10n.string("tendency.a11y.amount"), point.value)
                )
                .foregroundStyle(accent.gradient)
                .cornerRadius(4)
            }
        }
        // 原生 scrub：按下即选、拖动吸附最近数据点、松手把绑定置空
        .chartXSelection(value: $selectedDate)
        // 窗口由 scrollPosition 驱动（domain 固定为当前窗口），因此不使用
        // chartScrollableAxes / chartScrollPosition：避免与原生选择手势争抢拖动（详见 ScrubSupport.swift 顶部说明）
        .chartXVisibleDomain(length: visibleLength)
        .chartXScale(domain: viewDateRange)
        .chartYScale(domain: yAxisModel.domain)
        .chartXAxis { axisMarksContent }
        .chartYAxis { yAxisMarksContent }
        .chartOverlay { proxy in
            scrubOverlay(proxy: proxy)
        }
        .chartPlotStyle { plot in
            plot.background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(accent.opacity(0.06))
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string(titleKey))
        .accessibilityValue(accessibilityValueText)
        .accessibilityHint(L10n.string("tendency.a11y.hint"))
        .accessibilityChartDescriptor(ChartDescriptorRepresentable { chartDescriptor })
        .appAnimation(AppMotion.quick, value: selectedDate)
    }
    
    // MARK: - 坐标轴配置（使用 AxisContentBuilder）
    
    @AxisContentBuilder
    private var axisMarksContent: some AxisContent {
        switch visibleDays {
        case 1:
            // 小时视图
            let cal = Calendar.current
            let hourTimes: [Date] = [0, 6, 12, 18].compactMap {
                cal.date(byAdding: .hour, value: $0, to: viewDateRange.lowerBound)
            }
            AxisMarks(values: hourTimes) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(hourLabel(for: date))
                            .font(AppTypography.tiny)
                            .accessibilityHidden(true)
                    }
                }
            }
        case 2...7:
            // 周视图（R5：日粒度按天取刻度）
            AxisMarks(values: .stride(by: .day, count: 1)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(weekdayLabel(for: date))
                            .font(AppTypography.tiny)
                            .accessibilityHidden(true)
                    }
                }
            }
        case 8...31:
            // 月视图
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(dayOfMonthLabel(for: date))
                            .font(AppTypography.tiny)
                            .accessibilityHidden(true)
                    }
                }
            }
        case 32...180:
            // 半年视图
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(monthLabel(for: date, withSuffix: true))
                            .font(AppTypography.tiny)
                            .accessibilityHidden(true)
                    }
                }
            }
        case 181...364:
            // 接近一年
            AxisMarks(values: .stride(by: .month, count: 2)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(monthLabel(for: date, withSuffix: true))
                            .font(AppTypography.tiny)
                            .accessibilityHidden(true)
                    }
                }
            }
        default:
            // 一年视图
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(monthLabel(for: date, withSuffix: false))
                            .font(AppTypography.tiny)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }
    
    @AxisContentBuilder
    private var yAxisMarksContent: some AxisContent {
        // R4：显式刻度（3–5 条、整齐步长）；R9：数值轴放右侧，绘图区左边缘与卡片文字对齐
        AxisMarks(position: .trailing, values: yAxisModel.ticks) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(.secondary.opacity(0.12))
            AxisValueLabel {
                if let v = value.as(Double.self) {
                    Text(ChartAxisSupport.compactAmount(v, usesTenThousandUnit: usesTenThousandUnit))
                        .font(AppTypography.tiny)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
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
                        .fill(accent.opacity(0.45))
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
        let point = series.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
        VStack(alignment: .leading, spacing: 2) {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("¥\(formatAmount(point?.value ?? 0))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 选中变化：触觉门控 + 贴边判定

    private func handleSelectionChange(from oldValue: Date?, to newValue: Date?) {
        let dates = series.map(\.date)
        let oldIndex = oldValue.flatMap { ScrubSelection.index(of: $0, in: dates) }
        let newIndex = newValue.flatMap { ScrubSelection.index(of: $0, in: dates) }
        if ScrubSelection.shouldTick(from: oldIndex, to: newIndex) {
            HapticManager.shared.selectionChanged()
        }
        if let newValue { lastSelectedDate = newValue }
    }

    /// 贴边状态：-1 贴左（继续按住 → 往前翻）、1 贴右、0 不贴边；日 / 周档位不滚动
    private var edgeHold: Int {
        guard supportsHorizontalScroll, let selectedDate, !series.isEmpty else { return 0 }
        let dates = series.map(\.date)
        guard let index = ScrubSelection.index(of: selectedDate, in: dates) else { return 0 }
        return ScrubSelection.edgeHold(index: index, count: dates.count)
    }

    /// 只有「月 / 6 个月 / 年」档位支持贴边滚动；日 / 周保持仅选中数值
    private var supportsHorizontalScroll: Bool {
        visibleDays >= 30
    }

    /// 序列是否为「按月聚合」（6 个月 / 年档），决定贴边滚动的步长
    private var isMonthlySeries: Bool {
        guard series.count > 1 else { return false }
        return series[1].date.timeIntervalSince(series[0].date) > 20 * 86_400
    }

    /// 贴边继续按住时的窗口步进：原生选择手势不提供连续拖动增量，这里用 200ms 步进近似
    private func runEdgeAutoScroll() async {
        guard edgeHold != 0, supportsHorizontalScroll else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            let direction = edgeHold
            guard direction != 0 else { return }
            guard stepWindow(direction: direction) else { return }
        }
    }

    /// 推进一档窗口（按月图 = 1 个月，按天图 = 1 天），返回是否真的移动
    private func stepWindow(direction: Int) -> Bool {
        let calendar = Calendar.current
        let proposed: Date?
        if isMonthlySeries {
            proposed = calendar.date(byAdding: .month, value: direction, to: scrollPosition)
        } else {
            proposed = calendar.date(byAdding: .day, value: direction, to: scrollPosition)
        }
        guard let proposed else { return false }
        let clamped = clampedScrollDate(proposed)
        guard clamped != scrollPosition else { return false }
        scrollPosition = clamped
        // 选中态跟随新的窗口边缘，保持「贴边继续扫读」的体感
        selectedDate = clamped
        return true
    }

    /// 不滚出数据范围（完整数据范围 → 今天）
    private func clampedScrollDate(_ date: Date) -> Date {
        let today = Date().startOfDay
        let earliest = scrollBounds.lowerBound.startOfDay
        let latest = min(today, scrollBounds.upperBound.startOfDay)
        guard earliest <= latest else { return latest }
        let day = date.startOfDay
        if day < earliest { return earliest }
        if day > latest { return latest }
        return day
    }

    // MARK: - 无障碍

    private var accessibilityValueText: String {
        guard let point = selectedPoint else {
            let total = series.reduce(0) { $0 + $1.value }
            return String(format: L10n.string("tendency.a11y.summary"), formatAmount(total))
        }
        return String(format: L10n.string("tendency.a11y.selected"),
                      point.date.formatted(date: .abbreviated, time: .omitted),
                      formatAmount(point.value))
    }

    /// R18：图表描述符（标题 + 摘要 + 逐点标签 + Audio Graph）
    private var chartDescriptor: AXChartDescriptor {
        ChartAccessibility.barDescriptor(
            title: L10n.string(titleKey),
            summary: accessibilityValueText,
            valueLabel: L10n.string("tendency.a11y.amount"),
            points: series.map { (date: $0.date, value: $0.value) }
        )
    }
    
    // MARK: - 数据处理

    private func selectedText(for point: DailyAmount) -> String {
        let dateText = point.date.formatted(date: .abbreviated, time: .omitted)
        return "\(dateText)  ·  ¥\(formatAmount(point.value))"
    }
    
    private func formatAmount(_ value: Double) -> String {
        Self.amountFormatter.maximumFractionDigits = value >= 1_000 ? 0 : 1
        Self.amountFormatter.minimumFractionDigits = 0
        return Self.amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
    
    // MARK: - 日期标签
    
    private func hourLabel(for date: Date) -> String {
        let hour = Self.dateFormatter(for: "H").string(from: date)
        return isChineseLocale ? "\(hour)时" : "\(hour):00"
    }
    
    private func weekdayLabel(for date: Date) -> String {
        Self.dateFormatter(for: "EEE").string(from: date)
    }
    
    private func dayOfMonthLabel(for date: Date) -> String {
        let day = Self.dateFormatter(for: "d").string(from: date)
        return isChineseLocale ? "\(day)日" : day
    }
    
    private func monthLabel(for date: Date, withSuffix: Bool) -> String {
        let month = Self.dateFormatter(for: "M").string(from: date)
        if isChineseLocale, withSuffix { return "\(month)月" }
        if isChineseLocale { return month }
        if withSuffix { return Self.dateFormatter(for: "MMM").string(from: date) }
        return month
    }
    
    private var isChineseLocale: Bool {
        if #available(iOS 16, *) {
            let lang = Locale.autoupdatingCurrent.language.languageCode?.identifier ?? ""
            return lang.hasPrefix("zh")
        } else {
            let lang = Locale.autoupdatingCurrent.languageCode ?? ""
            return lang.hasPrefix("zh")
        }
    }
}
