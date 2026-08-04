//
//  TendencyChartView.swift
//  iFinance
//

import SwiftUI
import Charts

/// 趋势图表视图（支持折线图和柱状图）
struct TendencyChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - 数据
    
    let series: [DailyAmount]
    let accent: Color
    let visibleDays: Int
    let isHourly: Bool
    
    // MARK: - 交互状态
    
    @Binding var selectedDate: Date?
    @Binding var scrollPosition: Date
    @Binding var chartType: ChartDisplayType
    
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
        selectedDate: Binding<Date?>,
        scrollPosition: Binding<Date>,
        chartType: Binding<ChartDisplayType>
    ) {
        self.series = series
        self.accent = accent
        self.visibleDays = visibleDays
        self.isHourly = isHourly
        self._selectedDate = selectedDate
        self._scrollPosition = scrollPosition
        self._chartType = chartType
    }
    
    // MARK: - 视图
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图表类型切换
            HStack {
                Spacer()
                Picker("", selection: $chartType) {
                    ForEach(ChartDisplayType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: TendencyConstants.chartTypePickerWidth)
            }
            
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
                    .animation(.easeInOut(duration: 0.3), value: chartType)
            }
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
    
    // MARK: - 子视图
    
    @ViewBuilder
    private var chartContent: some View {
        if chartType == .bar {
            barChartView
        } else {
            lineChartView
        }
    }
    
    @ViewBuilder
    private var noDataPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.06))
                .frame(height: TendencyConstants.chartHeight)
                .blur(radius: 12)
            
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("tendency.no_data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: TendencyConstants.chartHeight)
    }
    
    // MARK: - 折线图
    
    @ViewBuilder
    private var lineChartView: some View {
        Chart {
            ForEach(series) { point in
                LineMark(
                    x: .value("date", point.date),
                    y: .value("amount", point.value)
                )
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(accent)
            }
            
            if let focus = selectedPoint {
                RuleMark(x: .value("focus", focus.date))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                
                PointMark(
                    x: .value("focus-date", focus.date),
                    y: .value("focus-value", focus.value)
                )
                .symbolSize(64)
                .foregroundStyle(accent)
                .annotation(position: .top, alignment: .center) {
                    annotationLabel(value: focus.value)
                }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: visibleLength)
        .chartXScale(domain: viewDateRange)
        .chartXAxis { axisMarksContent }
        .chartYAxis { yAxisMarksContent }
        .chartOverlay { proxy in
            chartGestureOverlay(proxy: proxy)
        }
        .chartPlotStyle { plot in
            plot.background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent.opacity(0.06))
            )
        }
        .padding(.horizontal, TendencyConstants.chartHorizontalPadding)
    }
    
    // MARK: - 柱状图
    
    @ViewBuilder
    private var barChartView: some View {
        Chart {
            ForEach(series) { point in
                BarMark(
                    x: .value("date", point.date),
                    y: .value("amount", point.value)
                )
                .foregroundStyle(accent.gradient)
                .cornerRadius(4)
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: visibleLength)
        .chartXScale(domain: viewDateRange)
        .chartXAxis { axisMarksContent }
        .chartYAxis { yAxisMarksContent }
        .chartPlotStyle { plot in
            plot.background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent.opacity(0.06))
            )
        }
        .padding(.horizontal, TendencyConstants.chartHorizontalPadding)
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
                    .foregroundStyle(.secondary.opacity(0.22))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(hourLabel(for: date))
                            .font(.caption2)
                    }
                }
            }
        case 2...7:
            // 周视图
            AxisMarks(values: .automatic) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.22))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(weekdayLabel(for: date))
                            .font(.caption2)
                    }
                }
            }
        case 8...31:
            // 月视图
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.22))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(dayOfMonthLabel(for: date))
                            .font(.caption2)
                    }
                }
            }
        case 32...180:
            // 半年视图
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.22))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(monthLabel(for: date, withSuffix: true))
                            .font(.caption2)
                    }
                }
            }
        case 181...364:
            // 接近一年
            AxisMarks(values: .stride(by: .month, count: 2)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.22))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(monthLabel(for: date, withSuffix: true))
                            .font(.caption2)
                    }
                }
            }
        default:
            // 一年视图
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.secondary.opacity(0.22))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(monthLabel(for: date, withSuffix: false))
                            .font(.caption2)
                    }
                }
            }
        }
    }
    
    @AxisContentBuilder
    private var yAxisMarksContent: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                .foregroundStyle(.secondary.opacity(0.12))
            AxisValueLabel {
                if let v = value.as(Double.self) {
                    Text(formatAmount(v)).font(.caption2)
                }
            }
        }
    }
    
    // MARK: - 手势处理
    
    @ViewBuilder
    private func chartGestureOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let frame = proxy.plotFrame else { return }
                            let plotOrigin = geometry[frame].origin
                            let plotSize = geometry[frame].size
                            let x = value.location.x - plotOrigin.x
                            let y = value.location.y - plotOrigin.y
                            
                            guard x >= 0, x <= plotSize.width, y >= 0, y <= plotSize.height,
                                  let date: Date = proxy.value(atX: x, as: Date.self),
                                  let nearest = series.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) else {
                                return
                            }
                            
                            let px = proxy.position(forX: nearest.date) ?? x
                            let dx = px - x
                            if dx * dx <= TendencyConstants.touchDetectionRadius * TendencyConstants.touchDetectionRadius {
                                selectedDate = nearest.date
                            }
                        }
                )
        }
    }
    
    // MARK: - 辅助视图
    
    @ViewBuilder
    private func annotationLabel(value: Double) -> some View {
        Text("¥\(formatAmount(value))")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.72) : Color.white.opacity(0.95))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.25 : 0.75), lineWidth: 0.8)
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
