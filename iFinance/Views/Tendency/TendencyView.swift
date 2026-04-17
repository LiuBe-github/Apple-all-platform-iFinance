import SwiftUI
import Charts
internal import CoreData

private struct DailyAmount: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private struct SpanOption: Identifiable, Hashable {
    let id = UUID()
    let titleKey: String
    let days: Int

    static let all: [SpanOption] = [
        .init(titleKey: "tendency.span_day", days: 1),
        .init(titleKey: "tendency.span_week", days: 7),
        .init(titleKey: "tendency.span_month", days: 30),
        .init(titleKey: "tendency.span_6month", days: 180),
        .init(titleKey: "tendency.span_year", days: 365)
    ]
}

struct TendencyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("UserProfileAvatarData") private var avatarData: Data?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: true)],
        animation: .default
    ) private var allBills: FetchedResults<Bill>

    @State private var expenseSpan: SpanOption = .all[1]
    @State private var incomeSpan: SpanOption = .all[1]

    @State private var expenseSelection: Date?
    @State private var incomeSelection: Date?
    @State private var expenseScrollPosition: Date = Date().startOfDay
    @State private var incomeScrollPosition: Date = Date().startOfDay

    @State private var dailyBillCounts: [Date: Int] = [:]

    private let trailingDays = 365

    // MARK: - 静态 NumberFormatter 缓存（避免每次渲染都重建）
    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .autoupdatingCurrent
        return f
    }()

    private func formatAmount(_ value: Double) -> String {
        Self.amountFormatter.maximumFractionDigits = value >= 1_000 ? 0 : 1
        Self.amountFormatter.minimumFractionDigits = 0
        return Self.amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private var expenseSeries: [DailyAmount] {
        buildDailySeries(for: "expenditure", trailingDays: trailingDays)
    }

    private var incomeSeries: [DailyAmount] {
        buildDailySeries(for: "income", trailingDays: trailingDays)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        trendCard(
                            titleKey: "tendency.expense",
                            accent: .pink,
                            series: expenseSeries,
                            billType: "expenditure",
                            span: $expenseSpan,
                            selectedDate: $expenseSelection,
                            scrollPosition: $expenseScrollPosition
                        )

                        trendCard(
                            titleKey: "tendency.income",
                            accent: .mint,
                            series: incomeSeries,
                            billType: "income",
                            span: $incomeSpan,
                            selectedDate: $incomeSelection,
                            scrollPosition: $incomeScrollPosition
                        )

                        heatmapCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("tab.tendency")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HeaderView(isTransactionView: false)
                }
            }
            .onAppear(perform: loadDatesWithBill)
            .onChange(of: allBills.count) { _, _ in
                loadDatesWithBill()
            }
        }
    }

    @ViewBuilder
    private func trendCard(
        titleKey: LocalizedStringKey,
        accent: Color,
        series: [DailyAmount],
        billType: String,
        span: Binding<SpanOption>,
        selectedDate: Binding<Date?>,
        scrollPosition: Binding<Date>
    ) -> some View {
        let visibleSeries = windowedSeries(
            series,
            around: scrollPosition.wrappedValue,
            days: span.wrappedValue.days
        )
        let dailySeries = span.wrappedValue.days == 1
            ? buildHourlySeries(for: billType, on: scrollPosition.wrappedValue)
            : series

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(titleKey)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("tendency.last_year")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: span) {
                ForEach(SpanOption.all) { item in
                    Text(LocalizedStringKey(item.titleKey)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: span.wrappedValue) { _, newSpan in
                scrollPosition.wrappedValue = Date().startOfDay
                selectedDate.wrappedValue = nil
            }

            metricsView(series: span.wrappedValue.days == 1 ? dailySeries : visibleSeries, accent: accent)

            if let selected = selectedPoint(in: span.wrappedValue.days == 1 ? dailySeries : visibleSeries, around: selectedDate.wrappedValue) {
                Text(selectedText(for: selected))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("tendency.drag_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if series.isEmpty {
                Text("tendency.no_data")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                continuousChart(
                    series: span.wrappedValue.days == 1 ? dailySeries : series,
                    accent: accent,
                    visibleDays: span.wrappedValue.days,
                    selectedDate: selectedDate,
                    scrollPosition: scrollPosition
                )
                .frame(height: 220)
            }
        }
        .padding(16)
        .appGlassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func continuousChart(
        series: [DailyAmount],
        accent: Color,
        visibleDays: Int,
        selectedDate: Binding<Date?>,
        scrollPosition: Binding<Date>
    ) -> some View {
        let visibleLength = TimeInterval(visibleDays * 86_400)
        let scrollStart = series.first?.date ?? Date().startOfDay
        let scrollEnd = series.last?.date ?? Date().startOfDay

        Chart {
            ForEach(series) { point in
                AreaMark(
                    x: .value("date", point.date),
                    y: .value("amount", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent.opacity(0.16), accent.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("date", point.date),
                    y: .value("amount", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(accent)
            }

            if let focus = selectedPoint(in: series, around: selectedDate.wrappedValue) {
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
                    Text("¥\(formatAmount(focus.value))")
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
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: scrollPosition)
        .chartXVisibleDomain(length: visibleLength)
        .chartXScale(domain: scrollStart...scrollEnd)
        .chartXAxis {
            if visibleDays == 1 {
                let start = scrollPosition.wrappedValue.startOfDay
                let cal = Calendar.current
                let values: [Date] = [0, 6, 12, 18].compactMap { cal.date(byAdding: .hour, value: $0, to: start) }
                AxisMarks(values: values) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.22))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(hourLabel(for: date))
                                .font(.caption2)
                        }
                    }
                }
            } else if visibleDays <= 7 {
                AxisMarks(values: .stride(by: .day, count: 1)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.22))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(weekdayLabel(for: date))
                                .font(.caption2)
                        }
                    }
                }
            } else if visibleDays <= 31 {
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
            } else if visibleDays <= 180 {
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
            } else if visibleDays < 365 {
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
            } else {
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
        .chartYAxis {
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
        .chartOverlay { proxy in
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
                                      let date: Date = proxy.value(atX: x),
                                      let nearest = selectedPoint(in: series, around: date) else {
                                    return
                                }
                                let px = proxy.position(forX: nearest.date) ?? x
                                let dx = px - x
                                if dx * dx <= 26 * 26 {
                                    selectedDate.wrappedValue = nearest.date
                                }
                            }
                    )
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.06))
                )
        }
        .padding(.horizontal, 6)
    }

    private func metricsView(series: [DailyAmount], accent: Color) -> some View {
        let values = series.map(\.value)
        let total = values.reduce(0, +)
        let nonZero = values.filter { $0 > 0 }
        let avg = nonZero.isEmpty ? 0 : nonZero.reduce(0, +) / Double(nonZero.count)

        return HStack(spacing: 10) {
            statPill(titleKey: "tendency.avg", value: "¥\(formatAmount(avg))", accent: accent)
            statPill(titleKey: "tendency.total", value: "¥\(formatAmount(total))", accent: accent.opacity(0.85))
        }
    }

    private func statPill(titleKey: LocalizedStringKey, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.1))
        }
    }

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("tendency.heatmap")
                    .font(.headline)
                Spacer()
                Text("tendency.one_year")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            githubHeatmapView
        }
        .padding(16)
        .appGlassCard(cornerRadius: 24)
    }

    private var githubHeatmapView: some View {
        let weeks = buildHeatmapWeeks()
        let monthLabels = buildHeatmapMonthLabels(from: weeks)

        return GeometryReader { geo in
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 0) {
                                ForEach(monthLabels, id: \.offset) { label in
                                    Text(label.title)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: CGFloat(label.span) * 16, alignment: .leading)
                                }
                            }

                            HStack(alignment: .top, spacing: 4) {
                                ForEach(weeks.indices, id: \.self) { weekIndex in
                                    VStack(spacing: 4) {
                                        ForEach(weeks[weekIndex].indices, id: \.self) { dayIndex in
                                            heatCellView(for: weeks[weekIndex][dayIndex])
                                        }
                                    }
                                    .id(weekIndex)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(minWidth: geo.size.width, alignment: .leading)
                    }
                    .onAppear {
                        if let lastIndex = weeks.indices.last {
                            proxy.scrollTo(lastIndex, anchor: .trailing)
                        }
                    }
                }
                .frame(width: geo.size.width, alignment: .leading)
                .clipped()
            }
        }
        .frame(height: 7 * 12 + 28)
    }

    private func heatCellView(for date: Date) -> some View {
        let level = heatLevel(for: date)
        let color = heatColor(level: level, date: date)
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 12, height: 12)
    }

    private func buildDailySeries(for type: String, trailingDays: Int) -> [DailyAmount] {
        let cal = Calendar.current
        let end = Date().startOfDay
        guard let start = cal.date(byAdding: .day, value: -(trailingDays - 1), to: end) else { return [] }

        var daily: [Date: Double] = [:]
        for bill in allBills {
            guard bill.type == type,
                  let date = bill.date,
                  date >= start,
                  date <= end else { continue }
            let key = cal.startOfDay(for: date)
            daily[key, default: 0] += bill.amount?.doubleValue ?? 0
        }

        return (0..<trailingDays).compactMap { idx in
            guard let date = cal.date(byAdding: .day, value: idx, to: start) else { return nil }
            return DailyAmount(date: date, value: daily[date, default: 0])
        }
    }

    private func selectedPoint(in series: [DailyAmount], around date: Date?) -> DailyAmount? {
        guard let date else { return nil }
        return series.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private func selectedText(for point: DailyAmount) -> String {
        let dateText = point.date.formatted(date: .abbreviated, time: .omitted)
        return "\(dateText)  ·  ¥\(formatAmount(point.value))"
    }

    private func windowedSeries(_ series: [DailyAmount], around endDate: Date, days: Int) -> [DailyAmount] {
        let end = endDate.startOfDay
        guard let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: end) else {
            return series
        }
        return series.filter { $0.date >= start && $0.date <= end }
    }

    private func buildHourlySeries(for billType: String, on date: Date) -> [DailyAmount] {
        let cal = Calendar.current
        let start = date.startOfDay
        return (0..<24).compactMap { hour in
            guard let hourDate = cal.date(byAdding: .hour, value: hour, to: start) else { return nil }
            return DailyAmount(date: hourDate, value: hourlyTotal(for: billType, hourStart: hourDate))
        }
    }

    private func hourlyTotal(for billType: String, hourStart: Date) -> Double {
        let cal = Calendar.current
        guard let hourEnd = cal.date(byAdding: .hour, value: 1, to: hourStart) else { return 0 }
        return allBills.reduce(0) { total, bill in
            guard bill.type == billType,
                  let date = bill.date,
                  date >= hourStart,
                  date < hourEnd else { return total }
            return total + (bill.amount?.doubleValue ?? 0)
        }
    }

    private func loadDatesWithBill() {
        let cal = Calendar.current
        let startDate = Calendar.current.date(byAdding: .day, value: -364, to: Date().startOfDay) ?? Date().startOfDay
        var counts: [Date: Int] = [:]
        for bill in allBills {
            guard let date = bill.date else { continue }
            let day = cal.startOfDay(for: date)
            guard day >= startDate else { continue }
            counts[day, default: 0] += 1
        }
        dailyBillCounts = counts
    }

    // MARK: - 日期格式化器（静态缓存，避免每次渲染都重建）

    private static var dateFormatters: [String: DateFormatter] = [:]

    private static func dateFormatter(for pattern: String) -> DateFormatter {
        if let cached = dateFormatters[pattern] { return cached }
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = pattern
        dateFormatters[pattern] = f
        return f
    }

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

    private func monthName(for month: Int) -> String {
        var comps = DateComponents()
        comps.month = month
        let date = Calendar.current.date(from: comps) ?? Date()
        return Self.dateFormatter(for: "MMM").string(from: date)
    }

    private func buildHeatmapWeeks() -> [[Date]] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let end = Date().startOfDay
        let start = cal.date(byAdding: .day, value: -364, to: end) ?? end
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start)) ?? start
        let weeks = 53

        return (0..<weeks).map { weekOffset in
            let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek) ?? startOfWeek
            return (0..<7).compactMap { dayOffset in
                cal.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
            }
        }
    }

    private func buildHeatmapMonthLabels(from weeks: [[Date]]) -> [(offset: Int, span: Int, title: String)] {
        guard !weeks.isEmpty else { return [] }
        var labels: [(offset: Int, span: Int, title: String)] = []
        var currentMonth: Int?
        var currentStart = 0

        for (index, week) in weeks.enumerated() {
            let month = Calendar.current.component(.month, from: week.first ?? Date())
            if currentMonth == nil {
                currentMonth = month
                currentStart = index
            } else if month != currentMonth {
                let span = max(1, index - currentStart)
                let title = monthName(for: currentMonth ?? month)
                labels.append((offset: currentStart, span: span, title: title))
                currentMonth = month
                currentStart = index
            }
        }
        if let currentMonth {
            let span = max(1, weeks.count - currentStart)
            labels.append((offset: currentStart, span: span, title: monthName(for: currentMonth)))
        }
        return labels
    }

    private func heatLevel(for date: Date) -> Int {
        let day = date.startOfDay
        let count = dailyBillCounts[day, default: 0]
        if count == 0 { return 0 }
        if count <= 1 { return 1 }
        if count <= 3 { return 2 }
        if count <= 6 { return 3 }
        return 4
    }

    private func heatColor(level: Int, date: Date) -> Color {
        let base: Color
        switch level {
        case 0: base = Color(UIColor.systemGray5)
        case 1: base = Color(red: 0.79, green: 0.88, blue: 1.0)
        case 2: base = Color(red: 0.56, green: 0.75, blue: 0.98)
        case 3: base = Color(red: 0.31, green: 0.56, blue: 0.95)
        default: base = Color(red: 0.15, green: 0.42, blue: 0.86)
        }
        return date.startOfDay > Date().startOfDay ? base.opacity(0.35) : base
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

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}

#Preview {
    TendencyView()
}
