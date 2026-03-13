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

    @State private var heatmapDates: [Date] = buildHeatmapDates()
    @State private var datesWithBill: Set<Date> = []

    private let trailingDays = 365

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
                            span: $expenseSpan,
                            selectedDate: $expenseSelection,
                            scrollPosition: $expenseScrollPosition
                        )

                        trendCard(
                            titleKey: "tendency.income",
                            accent: .mint,
                            series: incomeSeries,
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
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Group {
                            if let avatarData = avatarData,
                               let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 28))
                            }
                        }
                        .foregroundStyle(.blue)
                        .accessibilityLabel("header.edit_profile")
                    }
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
        span: Binding<SpanOption>,
        selectedDate: Binding<Date?>,
        scrollPosition: Binding<Date>
    ) -> some View {
        let visibleSeries = windowedSeries(
            series,
            around: scrollPosition.wrappedValue,
            days: span.wrappedValue.days
        )

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

            metricsView(series: visibleSeries, accent: accent)

            if let selected = selectedPoint(in: visibleSeries, around: selectedDate.wrappedValue) {
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
                    series: series,
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
        .chartXAxis {
            if visibleDays <= 31 {
                AxisMarks(values: .stride(by: .day, count: visibleDays <= 7 ? 1 : 7)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.22))
                    AxisValueLabel(format: .dateTime.month().day())
                        .font(.caption2)
                }
            } else if visibleDays <= 180 {
                AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.22))
                    AxisValueLabel(format: .dateTime.month().day())
                        .font(.caption2)
                }
            } else {
                AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.22))
                    AxisValueLabel(format: .dateTime.year().month())
                        .font(.caption2)
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
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let frame = proxy.plotFrame else { return }
                                let x = value.location.x - geometry[frame].origin.x
                                guard x >= 0, x <= geometry[frame].width,
                                      let date: Date = proxy.value(atX: x) else {
                                    return
                                }
                                selectedDate.wrappedValue = date
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

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(
                        rows: Array(repeating: GridItem(.fixed(20), spacing: 4), count: 7),
                        alignment: .top,
                        spacing: 6
                    ) {
                        ForEach(heatmapDates, id: \.self) { date in
                            heatCellView(for: date).id(date.startOfDay)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        proxy.scrollTo(Date().startOfDay, anchor: .trailing)
                    }
                }
            }
            .frame(height: 170)
        }
        .padding(16)
        .appGlassCard(cornerRadius: 24)
    }

    private func heatCellView(for date: Date) -> some View {
        let has = datesWithBill.contains(date.startOfDay)
        let day = Calendar.current.component(.day, from: date)
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(has ? Color.blue.opacity(0.82) : Color(UIColor.systemGray5).opacity(0.8))
            Text("\(day)")
                .font(.caption2)
                .fontWeight(has ? .semibold : .regular)
                .foregroundStyle(has ? .white : .secondary)
        }
        .frame(width: 20, height: 20)
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

    private func loadDatesWithBill() {
        let cal = Calendar.current
        let startDate = (heatmapDates.first ?? Date()).startOfDay
        datesWithBill = Set(
            allBills.compactMap { bill -> Date? in
                guard let date = bill.date else { return nil }
                let day = cal.startOfDay(for: date)
                return day >= startDate ? day : nil
            }
        )
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .autoupdatingCurrent
        formatter.maximumFractionDigits = value >= 1_000 ? 0 : 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private static func buildHeatmapDates() -> [Date] {
        let cal = Calendar.current
        let today = Date().startOfDay
        let start = cal.date(byAdding: .day, value: -364, to: today)!
        return (0...364).compactMap { cal.date(byAdding: .day, value: $0, to: start)?.startOfDay }
    }
}

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}

#Preview {
    TendencyView()
}
