//
//  TendencyChartView.swift
//  iFinance
//

import SwiftUI
import Charts

/// 趋势柱状图视图（原折线图已移除）
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

    // MARK: - 手势状态

    /// 手势模式：命中柱子 = 只切换数值；落在空白处 = 横向滚动时间窗口
    private enum DragMode {
        case none
        case select
        case scroll
    }

    @State private var dragMode: DragMode = .none
    @State private var dragStartScroll: Date?
    
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
        scrollPosition: Binding<Date>
    ) {
        self.series = series
        self.accent = accent
        self.visibleDays = visibleDays
        self.isHourly = isHourly
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
                    x: .value("date", point.date),
                    y: .value("amount", point.value)
                )
                .foregroundStyle(accent.gradient)
                .cornerRadius(4)
                .opacity(barOpacity(for: point))
            }
            
            if let focus = selectedPoint {
                RuleMark(x: .value("focus", focus.date))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                
                PointMark(
                    x: .value("focus-date", focus.date),
                    y: .value("focus-value", focus.value)
                )
                .symbolSize(90)
                .foregroundStyle(accent)
                .annotation(position: .top, alignment: .center) {
                    annotationLabel(value: focus.value)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
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
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(accent.opacity(0.06))
            )
        }
        .appAnimation(AppMotion.standard, value: selectedDate)
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

    // MARK: - 手势判定与处理

    /// 只有「月 / 6 个月 / 年」档位支持空白处横向滚动；日 / 周保持仅选中数值
    private var supportsHorizontalScroll: Bool {
        visibleDays >= 30
    }

    private func resolveDragMode(x: CGFloat, y: CGFloat, plotSize: CGSize, proxy: ChartProxy) -> DragMode {
        guard supportsHorizontalScroll else { return .select }
        let insideVertically = y >= 0 && y <= plotSize.height
        if insideVertically, isNearDataPoint(x: x, proxy: proxy) {
            return .select
        }
        return .scroll
    }

    /// 是否按在柱子附近（横向距离在触摸半径内）
    private func isNearDataPoint(x: CGFloat, proxy: ChartProxy) -> Bool {
        guard let date: Date = proxy.value(atX: x, as: Date.self),
              let nearest = series.min(by: {
                  abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
              }),
              let px = proxy.position(forX: nearest.date) else {
            return false
        }
        return abs(px - x) <= TendencyConstants.touchDetectionRadius
    }

    private func updateSelection(at x: CGFloat, proxy: ChartProxy) {
        guard let date: Date = proxy.value(atX: x, as: Date.self),
              let nearest = series.min(by: {
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

    /// 手指拖动换算成时间窗口位移（往右拖 = 看更早的数据）
    private func scrollWindow(from base: Date, translation: CGFloat, plotWidth: CGFloat) {
        guard plotWidth > 0 else { return }
        let daysShift = -Double(translation / plotWidth) * Double(visibleDays)
        let proposed = base.addingTimeInterval(daysShift * 86_400)
        scrollPosition = clampedScrollDate(proposed)
    }

    /// 不滚出数据范围（最早数据 ~ 今天）
    private func clampedScrollDate(_ date: Date) -> Date {
        let today = Date().startOfDay
        let earliest = series.first?.date.startOfDay ?? today
        let latest = min(today, series.last?.date.startOfDay ?? today)
        let day = date.startOfDay
        if day < earliest { return earliest }
        if day > latest { return latest }
        return day
    }
    
    // MARK: - 辅助视图
    
    @ViewBuilder
    private func annotationLabel(value: Double) -> some View {
        Text("¥\(formatAmount(value))")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .padding(.vertical, AppSpacing.xs)
            .padding(.horizontal, AppSpacing.sm)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.78) : Color.white.opacity(0.95))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.25 : 0.75), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 数据处理
    
    /// 柱状图非选中柱的淡化处理（小时视图按小时精确对比）
    private func barOpacity(for point: DailyAmount) -> Double {
        guard let selected = selectedDate else { return 1 }
        if isHourly {
            return point.date == selected ? 1 : 0.45
        }
        return Calendar.current.isDate(point.date, inSameDayAs: selected) ? 1 : 0.45
    }
    
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
