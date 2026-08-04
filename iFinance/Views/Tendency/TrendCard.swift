//
//  TrendCard.swift
//  iFinance
//

import SwiftUI
internal import CoreData

/// 趋势卡片视图（支出或收入）
struct TrendCard: View {
    // MARK: - 配置
    
    let titleKey: LocalizedStringKey
    let accent: Color
    let billType: String // "expenditure" or "income"
    
    // MARK: - 数据
    
    let allSeries: [DailyAmount]
    let allBills: FetchedResults<Bill>
    
    // MARK: - 状态
    
    @Binding var span: SpanOption
    @Binding var chartType: ChartDisplayType
    @Binding var selectedDate: Date?
    @Binding var scrollPosition: Date
    
    // MARK: - 格式化器
    
    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .autoupdatingCurrent
        return f
    }()
    
    // MARK: - 计算属性
    
    /// 实际显示的数据序列
    private var displaySeries: [DailyAmount] {
        if span.days == 1 {
            // 单日视图：显示小时数据
            return buildHourlySeries(on: scrollPosition)
        } else if span.days > 31 {
            // 长周期：按月聚合
            let windowed = windowedSeries(allSeries, days: span.days)
            return aggregateByMonth(windowed)
        } else {
            // 正常：窗口过滤
            return windowedSeries(allSeries, days: span.days)
        }
    }
    
    /// 用于指标计算的数据（不包含月聚合）
    private var metricsSeries: [DailyAmount] {
        if span.days == 1 {
            return buildHourlySeries(on: scrollPosition)
        } else {
            return windowedSeries(allSeries, days: span.days)
        }
    }
    
    // MARK: - 视图
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text(titleKey)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("tendency.last_year")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 时间段选择
            Picker("", selection: $span) {
                ForEach(SpanOption.all) { item in
                    Text(LocalizedStringKey(item.titleKey)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: span) { _, newSpan in
                // 切换时间段时重置状态
                scrollPosition = Date().startOfDay
                selectedDate = nil
            }
            
            // 统计指标
            metricsView
            
            // 图表
            TendencyChartView(
                series: displaySeries,
                accent: accent,
                visibleDays: span.days,
                isHourly: span.days == 1,
                selectedDate: $selectedDate,
                scrollPosition: $scrollPosition,
                chartType: $chartType
            )
        }
        .padding(TendencyConstants.cardPadding)
        .appGlassCard(cornerRadius: TendencyConstants.cardCornerRadius)
    }
    
    // MARK: - 子视图
    
    @ViewBuilder
    private var metricsView: some View {
        let values = metricsSeries.map(\.value)
        let total = values.reduce(0, +)
        let nonZero = values.filter { $0 > 0 }
        let avg = nonZero.isEmpty ? 0 : nonZero.reduce(0, +) / Double(nonZero.count)
        
        HStack(spacing: 10) {
            statPill(titleKey: "tendency.avg", value: "¥\(formatAmount(avg))", accent: accent)
            statPill(titleKey: "tendency.total", value: "¥\(formatAmount(total))", accent: accent.opacity(0.85))
        }
    }
    
    @ViewBuilder
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
            RoundedRectangle(cornerRadius: TendencyConstants.statPillCornerRadius, style: .continuous)
                .fill(accent.opacity(0.1))
        }
    }
    
    // MARK: - 数据处理
    
    private func hourlyTotal(hourStart: Date, for billType: String) -> Double {
        let cal = Calendar.current
        guard let hourEnd = cal.date(byAdding: .hour, value: 1, to: hourStart) else { return 0 }
        
        var total: Double = 0
        for bill in allBills {
            guard bill.type == billType, let date = bill.date else {
                continue
            }
            // 获取账单日期的小时开始时间
            let components = cal.dateComponents([.year, .month, .day, .hour], from: date)
            guard let billHourStart = cal.date(from: components) else {
                continue
            }
            // 判断账单是否在这个小时内
            if billHourStart >= hourStart && billHourStart < hourEnd {
                total += bill.amount?.doubleValue ?? 0
            }
        }
        return total
    }
    
    private func buildHourlySeries(on date: Date) -> [DailyAmount] {
        let cal = Calendar.current
        let start = date.startOfDay
        
        return (0..<24).compactMap { hour in
            guard let hourDate = cal.date(byAdding: .hour, value: hour, to: start) else {
                return nil
            }
            return DailyAmount(date: hourDate, value: hourlyTotal(hourStart: hourDate, for: billType))
        }
    }
    
    private func windowedSeries(_ series: [DailyAmount], days: Int) -> [DailyAmount] {
        let end = scrollPosition.startOfDay
        guard let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: end) else {
            return series
        }
        return series.filter {
            $0.date >= start && $0.date <= end
        }
    }
    
    private func aggregateByMonth(_ series: [DailyAmount]) -> [DailyAmount] {
        let cal = Calendar.current
        var monthly: [Date: Double] = [:]
        
        for point in series {
            let components = cal.dateComponents([.year, .month], from: point.date)
            guard let monthStart = cal.date(from: components) else { continue }
            monthly[monthStart, default: 0] += point.value
        }
        
        return monthly
            .map { DailyAmount(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    private func formatAmount(_ value: Double) -> String {
        Self.amountFormatter.maximumFractionDigits = value >= 1_000 ? 0 : 1
        Self.amountFormatter.minimumFractionDigits = 0
        return Self.amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
