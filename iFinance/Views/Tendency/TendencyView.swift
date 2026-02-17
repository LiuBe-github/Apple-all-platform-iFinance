//
//  TendencyView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
import Charts
internal import CoreData

// MARK: - DateFormatter 复用
private extension DateFormatter {
    static let yearMonth: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年MM月"; return f
    }()
    static let month: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月"; return f
    }()
    static let fullDate: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"; return f
    }()
}

// MARK: - View 条件修饰器
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - 滑动图表容器
/// 封装连续跟手滑动逻辑，暴露当前偏移量 offset（整数页）供父视图使用
private struct SwipeChartContainer<ChartContent: View>: View {
    let offset: Int                          // 当前页（父视图控制）
    let maxOffset: Int                       // 最大页数限制（负无穷到 0）
    let onOffsetChange: (Int) -> Void        // 翻页回调
    @ViewBuilder let content: () -> ChartContent
    
    // 拖拽过程中的实时像素偏移
    @State private var dragTranslation: CGFloat = 0
    // 记录上次 snap 时的页索引，用于跟手时实时预算目标页
    @State private var baseOffset: Int = 0
    
    // 每页宽度（在 GeometryReader 中获取）
    @State private var pageWidth: CGFloat = 300
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // 当前页内容
                content()
                    .frame(width: w)
                    .offset(x: dragTranslation)
                
                // 左右箭头
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.35))
                    Spacer()
                    if offset < 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.35))
                    }
                }
                .padding(.horizontal, 4)
                .allowsHitTesting(false)
            }
            .onAppear { pageWidth = w }
            .onChange(of: geo.size.width) { _, newWidth in pageWidth = newWidth }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let x = value.translation.width
                        // 向右（未来方向）且已在最新页：阻尼
                        if x > 0 && offset >= 0 {
                            dragTranslation = x * 0.12
                        } else {
                            dragTranslation = x
                        }
                        // 实时计算应展示哪一页并通知父视图
                        let pageDelta = Int((-x / pageWidth).rounded())
                        let candidate = (baseOffset + pageDelta).clamped(to: maxOffset...0)
                        if candidate != offset {
                            onOffsetChange(candidate)
                        }
                    }
                    .onEnded { value in
                        // 最终 snap
                        let x     = value.predictedEndTranslation.width
                        let delta = Int((-x / pageWidth).rounded())
                        let final = (baseOffset + delta).clamped(to: maxOffset...0)
                        onOffsetChange(final)
                        baseOffset = final
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            dragTranslation = 0
                        }
                    }
            )
        }
    }
}

// MARK: - Comparable clamped helper
private extension Comparable {
    func clamped(to range: PartialRangeThrough<Self>) -> Self { min(self, range.upperBound) }
    func clamped(to range: ClosedRange<Self>) -> Self { max(range.lowerBound, min(self, range.upperBound)) }
}

// MARK: - 主视图
struct TendencyView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedIncomeTimeRange  = "6个月"
    @State private var selectedExpenseTimeRange = "周"
    
    // 页偏移：0 = 当前页，负数 = 过去的页
    @State private var incomeOffset  = 0
    @State private var expenseOffset = 0
    
    @State private var heatmapDates:  [Date]    = TendencyView.buildHeatmapDates()
    @State private var datesWithBill: Set<Date> = []
    
    let timeRanges = ["日", "周", "月", "6个月", "年"]
    /// 最多向过去翻多少页（避免无限追溯）
    let maxHistoryPages = -200
    
    // MARK: 数据
    private var incomeData: [ChartDataPoint] {
        fetchBills(type: "income", range: selectedIncomeTimeRange, offset: incomeOffset)
    }
    private var expenseData: [ChartDataPoint] {
        fetchBills(type: "expenditure", range: selectedExpenseTimeRange, offset: expenseOffset)
    }
    
    private static func buildHeatmapDates() -> [Date] {
        let cal   = Calendar.current
        let today = Date().startOfDay
        let start = cal.date(byAdding: .day, value: -364, to: today)!
        return (0...364).compactMap { cal.date(byAdding: .day, value: $0, to: start)?.startOfDay }
    }
    
    // MARK: - 锚点日期（当前页末尾）
    private func anchorDate(range: String, offset: Int) -> Date {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch range {
        case "日":    return cal.date(byAdding: .day,   value: offset,     to: today)!
        case "周":    return cal.date(byAdding: .day,   value: offset * 7, to: today)!
        case "月":    return cal.date(byAdding: .month, value: offset,     to: today)!
        case "6个月": return cal.date(byAdding: .month, value: offset * 6, to: today)!
        case "年":    return cal.date(byAdding: .year,  value: offset,     to: today)!
        default:      return today
        }
    }
    
    // MARK: - 日期范围文字
    private func dateRangeText(range: String, offset: Int) -> String {
        let cal    = Calendar.current
        let anchor = anchorDate(range: range, offset: offset)
        
        switch range {
        case "日":
            return DateFormatter.fullDate.string(from: anchor)
            
        case "周":
            let start = cal.date(byAdding: .day, value: -6, to: anchor)!
            return rangeString(from: start, to: anchor)
            
        case "月":
            let start = cal.date(byAdding: .day, value: -29, to: anchor)!
            return rangeString(from: start, to: anchor)
            
        case "6个月":
            let endMonth   = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
            let startMonth = cal.date(byAdding: .month, value: -5, to: endMonth)!
            return "\(DateFormatter.yearMonth.string(from: startMonth))至\(DateFormatter.yearMonth.string(from: endMonth))"
            
        case "年":
            return "\(cal.component(.year, from: anchor))年全年"
            
        default: return ""
        }
    }
    
    private func rangeString(from start: Date, to end: Date) -> String {
        let cal = Calendar.current
        let sc  = cal.dateComponents([.year, .month, .day], from: start)
        let ec  = cal.dateComponents([.year, .month, .day], from: end)
        if sc.year == ec.year && sc.month == ec.month {
            return "\(ec.year!)年\(ec.month!)月\(sc.day!)日至\(ec.day!)日"
        }
        return "\(DateFormatter.fullDate.string(from: start))至\(DateFormatter.fullDate.string(from: end))"
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // 支出趋势
                Section(header: Text("支出趋势").font(.headline)) {
                    Picker("", selection: $selectedExpenseTimeRange) {
                        ForEach(timeRanges, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedExpenseTimeRange) { expenseOffset = 0 }
                    
                    averageView(data: expenseData, color: .red)
                    
                    Text(dateRangeText(range: selectedExpenseTimeRange, offset: expenseOffset))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                    
                    chartCard(
                        data: expenseData,
                        color: .red,
                        emptyText: "暂无支出记录",
                        range: selectedExpenseTimeRange,
                        offset: $expenseOffset
                    )
                }
                
                // 收入趋势
                Section(header: Text("收入趋势").font(.headline)) {
                    Picker("", selection: $selectedIncomeTimeRange) {
                        ForEach(timeRanges, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedIncomeTimeRange) { incomeOffset = 0 }
                    
                    averageView(data: incomeData, color: .green)
                    
                    Text(dateRangeText(range: selectedIncomeTimeRange, offset: incomeOffset))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                    
                    chartCard(
                        data: incomeData,
                        color: .green,
                        emptyText: "暂无收入记录",
                        range: selectedIncomeTimeRange,
                        offset: $incomeOffset
                    )
                }
                
                // 热力图
                Section(header: Text("记账热力图（近一年）").font(.headline)) {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(
                                rows: Array(repeating: GridItem(.fixed(28), spacing: 2), count: 7),
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
                            loadDatesWithBill()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(Date().startOfDay, anchor: .trailing)
                            }
                        }
                    }
                    .frame(height: 220)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HeaderView(isTransactionView: false)
                }
            }
            .navigationTitle("趋势")
        }
    }
    
    // MARK: - 图表卡片（含空状态 + 滑动容器）
    @ViewBuilder
    private func chartCard(
        data: [ChartDataPoint],
        color: Color,
        emptyText: String,
        range: String,
        offset: Binding<Int>
    ) -> some View {
        let chartH: CGFloat = 180
        let axisH:  CGFloat = 32
        let total           = chartH + axisH
        
        if data.isEmpty {
            Text(emptyText)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            SwipeChartContainer(
                offset: offset.wrappedValue,
                maxOffset: maxHistoryPages,
                onOffsetChange: { offset.wrappedValue = $0 }
            ) {
                chartInner(data: data, color: color, range: range,
                           chartHeight: chartH, axisLabelHeight: axisH)
            }
            .frame(height: total)
        }
    }
    
    // MARK: - 图表内容
    @ViewBuilder
    private func chartInner(
        data: [ChartDataPoint],
        color: Color,
        range: String,
        chartHeight: CGFloat,
        axisLabelHeight: CGFloat
    ) -> some View {
        let needsScroll = data.count > barCount(for: range)
        Group {
            if needsScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    barChart(data: data, color: color,
                             fixedWidth: CGFloat(data.count) * 60 + 40,
                             height: chartHeight, range: range)
                }
                .padding(.bottom, axisLabelHeight)
            } else {
                barChart(data: data, color: color, fixedWidth: nil,
                         height: chartHeight, range: range)
                .padding(.bottom, axisLabelHeight)
            }
        }
        .frame(height: chartHeight + axisLabelHeight)
    }
    
    // MARK: - 纯柱状图
    @ViewBuilder
    private func barChart(
        data: [ChartDataPoint],
        color: Color,
        fixedWidth: CGFloat?,
        height: CGFloat,
        range: String
    ) -> some View {
        Chart {
            ForEach(data) { item in
                BarMark(x: .value("时间", item.label), y: .value("金额", item.value))
                    .foregroundStyle(color)
                    .cornerRadius(4)
            }
        }
        .chartXAxis {
            if range == "月" {
                let values = data.enumerated().filter { $0.offset % 7 == 0 }.map { $0.element.label }
                AxisMarks(values: values) { _ in
                    AxisGridLine()
                    AxisValueLabel(centered: true).font(.caption2)
                }
            } else {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(centered: true).font(.caption2)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(formatY(v)).font(.caption2) }
                }
            }
        }
        .if(fixedWidth != nil) { $0.frame(width: fixedWidth) }
        .frame(maxWidth: fixedWidth == nil ? .infinity : fixedWidth, maxHeight: height)
        .padding(.horizontal, 4)
    }
    
    // MARK: - 平均值
    @ViewBuilder
    private func averageView(data: [ChartDataPoint], color: Color) -> some View {
        if !data.isEmpty {
            let nonZero = data.filter { $0.value > 0 }
            let avg     = nonZero.isEmpty ? 0.0 : nonZero.reduce(0) { $0 + $1.value } / Double(nonZero.count)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("均值").font(.subheadline).foregroundColor(.secondary)
                Text("¥\(formatAvg(avg))")
                    .font(.title2).fontWeight(.semibold).foregroundColor(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
    
    // MARK: - 格式化
    private func formatY(_ v: Double) -> String {
        if v >= 10_000 { let w = v/10_000; return w == w.rounded() ? "\(Int(w))万" : String(format:"%.1f万",w) }
        if v >= 1_000  { let q = v/1_000;  return q == q.rounded() ? "\(Int(q))千" : String(format:"%.1f千",q) }
        if v == 0 { return "0" }
        return v.truncatingRemainder(dividingBy:1) == 0 ? "\(Int(v))" : String(format:"%.1f",v)
    }
    
    private func formatAvg(_ v: Double) -> String {
        if v >= 10_000 { let w = v/10_000; return w.truncatingRemainder(dividingBy:1)==0 ? "\(Int(w))万" : String(format:"%.2f万",w) }
        return v.truncatingRemainder(dividingBy:1)==0 ? "\(Int(v))" : String(format:"%.2f",v)
    }
    
    private func barCount(for range: String) -> Int {
        switch range {
        case "日":return 4; case "周":return 7; case "月":return 30
        case "6个月":return 6; case "年":return 12; default:return 6
        }
    }
    
    // MARK: - 热力图格子
    private func heatCellView(for date: Date) -> some View {
        let has = datesWithBill.contains(date.startOfDay)
        let day = Calendar.current.component(.day, from: date)
        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(has ? Color.blue : Color(UIColor.systemGray5))
            Text("\(day)").font(.caption2)
                .fontWeight(has ? .medium : .regular)
                .foregroundColor(has ? .white : .gray)
        }
        .frame(width: 28, height: 28)
    }
    
    private func loadDatesWithBill() {
        let cal = Calendar.current
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", (heatmapDates.first ?? Date()) as NSDate)
        request.propertiesToFetch = ["date"]
        do {
            let bills = try viewContext.fetch(request)
            datesWithBill = Set(bills.compactMap { $0.date.map { cal.startOfDay(for: $0) } })
        } catch { print("❌ \(error)") }
    }
    
    // MARK: - 数据获取
    private func fetchBills(type: String, range: String, offset: Int) -> [ChartDataPoint] {
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "type == %@", type),
            NSPredicate(format: "date >= %@", twoYearsAgo as NSDate)
        ])
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        do { return groupByPeriod(try viewContext.fetch(request), range: range, offset: offset) }
        catch { print("❌ \(error)"); return [] }
    }
    
    // MARK: - 聚合
    private func groupByPeriod(_ bills: [Bill], range: String, offset: Int) -> [ChartDataPoint] {
        guard !bills.isEmpty else { return [] }
        let cal    = Calendar.current
        let anchor = anchorDate(range: range, offset: offset)
        
        func total(_ b: [Bill]) -> Double { b.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) } }
        func billsIn(start: Date, end: Date) -> [Bill] {
            bills.filter { guard let d = $0.date else { return false }; return d >= start && d < end }
        }
        
        switch range {
        case "日":
            let dayStart = cal.startOfDay(for: anchor)
            return [(0,6,"凌晨"),(6,12,"上午"),(12,18,"下午"),(18,24,"晚上")].map { sh, eh, label in
                let s = cal.date(bySettingHour: sh, minute: 0, second: 0, of: dayStart)!
                let e = eh == 24 ? cal.date(byAdding: .day, value: 1, to: dayStart)!
                : cal.date(bySettingHour: eh, minute: 0, second: 0, of: dayStart)!
                return ChartDataPoint(label: label, value: total(billsIn(start: s, end: e)))
            }
            
        case "周":
            let weekStart       = cal.date(byAdding: .day, value: -6, to: anchor)!
            let weekdays        = ["周日","周一","周二","周三","周四","周五","周六"]
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }.map { day in
                let e = cal.date(byAdding: .day, value: 1, to: day)!
                return ChartDataPoint(label: weekdays[cal.component(.weekday, from: day)-1],
                                      value: total(billsIn(start: day, end: e)))
            }
            
        case "月":
            let monthStart = cal.date(byAdding: .day, value: -29, to: anchor)!
            return (0..<30).compactMap { cal.date(byAdding: .day, value: $0, to: monthStart) }.map { day in
                let e = cal.date(byAdding: .day, value: 1, to: day)!
                let m = cal.component(.month, from: day)
                let d = cal.component(.day,   from: day)
                return ChartDataPoint(label: "\(m)月\(d)日", value: total(billsIn(start: day, end: e)))
            }
            
        case "6个月":
            let endMonth = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
            return (0..<6)
                .compactMap { cal.date(byAdding: .month, value: -$0, to: endMonth) }
                .reversed()
                .compactMap { ref -> ChartDataPoint? in
                    guard let end = cal.date(byAdding: .month, value: 1, to: ref) else { return nil }
                    return ChartDataPoint(label: DateFormatter.month.string(from: ref),
                                          value: total(billsIn(start: ref, end: end)))
                }
            
        case "年":
            let year = cal.component(.year, from: anchor)
            return (1...12).compactMap { month -> ChartDataPoint? in
                var c = DateComponents(); c.year = year; c.month = month; c.day = 1
                guard let s = cal.date(from: c), let e = cal.date(byAdding: .month, value: 1, to: s) else { return nil }
                return ChartDataPoint(label: DateFormatter.month.string(from: s),
                                      value: total(billsIn(start: s, end: e)))
            }
            
        default: return []
        }
    }
}

// MARK: - 数据模型
struct ChartDataPoint: Identifiable {
    let id = UUID(); let label: String; let value: Double
}

// MARK: - Date 扩展
extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}

// MARK: - 预览
#Preview { TendencyView() }
