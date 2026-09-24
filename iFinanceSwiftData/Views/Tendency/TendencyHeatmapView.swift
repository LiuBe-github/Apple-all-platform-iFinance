//
//  TendencyHeatmapView.swift
//  iFinance
//
//  GitHub 风格热力图（增强交互版）
//

import SwiftUI

/// GitHub 风格的热力图视图
struct TendencyHeatmapView: View {

    /// 月份标签格式化器（静态复用，避免每个格子新建）
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "MMM"
        return f
    }()

    /// 每日账单计数（用于计算热力等级）
    let dailyBillCounts: [Date: Int]
    
    // MARK: - 交互状态
    
    @State private var selectedCellDate: Date?
    @State private var cellsAppeared = false
    
    // MARK: - 私有计算属性
    
    private var weeks: [[Date]] {
        buildHeatmapWeeks()
    }
    
    private var monthLabels: [(offset: Int, span: Int, title: String)] {
        buildHeatmapMonthLabels(from: weeks)
    }
    
    // MARK: - 视图
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("tendency.heatmap")
                    .font(.headline)
                Spacer()
                Text("tendency.one_year")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            heatmapGrid
            
            legendRow
        }
        .padding(TendencyConstants.cardPadding)
        .appGlassCard(cornerRadius: TendencyConstants.cardCornerRadius)
    }
    
    // MARK: - 图例
    
    private var legendRow: some View {
        HStack(spacing: AppSpacing.sm) {
            Spacer()
            Text(L10n.string("tendency.heatmap_less"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            ForEach(0..<5) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(heatColor(level: level))
                    .frame(width: AppLayout.heatmapCell, height: AppLayout.heatmapCell)
            }
            Text(L10n.string("tendency.heatmap_more"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
    
    // MARK: - 子视图
    
    @ViewBuilder
    private var heatmapGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // 选中提示条
            ZStack {
                if let selected = selectedCellDate {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(selected.formatted(.dateTime.month().day().weekday(.abbreviated)))
                            .font(.caption.weight(.medium))
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("\(dailyBillCounts[selected.startOfDay, default: 0])")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                        Text(L10n.string("tendency.heatmap_bills"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.blue.opacity(0.3), lineWidth: 0.8)
                    )
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .appAnimation(AppMotion.standard, value: selectedCellDate)
            
            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            // 月份标签（放在 ScrollView 内部，跟随滚动）
                            monthLabelsView
                            
                            // 热力图网格
                            HStack(alignment: .top, spacing: AppSpacing.xs) {
                                ForEach(weeks.indices, id: \.self) { weekIndex in
                                    VStack(spacing: AppSpacing.xs) {
                                        ForEach(weeks[weekIndex].indices, id: \.self) { dayIndex in
                                            heatCell(for: weeks[weekIndex][dayIndex], index: weekIndex * 7 + dayIndex)
                                        }
                                    }
                                    .id(weekIndex)
                                }
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                        .frame(width: totalHeatmapWidth, alignment: .leading)
                    }
                    .onAppear {
                        if let lastIndex = weeks.indices.last {
                            proxy.scrollTo(lastIndex, anchor: .trailing)
                        }
                        withAnimation(AppMotion.standard) {
                            cellsAppeared = true
                        }
                    }
                }
            }
            .frame(height: 7 * AppLayout.heatmapCell + 40) // 7 天 × 单元格 + 月份标签高度
        }
    }
    
    /// 月份标签视图（跟随热力图滚动）
    @ViewBuilder
    private var monthLabelsView: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(monthLabels, id: \.offset) { label in
                Text(label.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: CGFloat(label.span) * 16, alignment: .leading)
            }
        }
    }
    
    /// 热力图总宽度（用于 frame 对齐）
    private var totalHeatmapWidth: CGFloat {
        CGFloat(weeks.count) * 16 // 每列 16px (12px格子 + 4px间距)
    }
    
    @ViewBuilder
    private func heatCell(for date: Date, index: Int) -> some View {
        let level = heatLevel(for: date)
        let color = heatColor(level: level, date: date)
        let isSelected = selectedCellDate?.startOfDay == date.startOfDay
        
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: TendencyConstants.heatmapCellSize, height: TendencyConstants.heatmapCellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 1.6)
            )
            .scaleEffect(isSelected ? 1.22 : 1)
            .opacity(cellsAppeared ? 1 : 0)
            .appAnimation(AppMotion.emphasized.delay(AppMotion.entranceDelay(index: index)), value: cellsAppeared)
            .appAnimation(AppMotion.quick, value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.shared.selectionChanged()
                withAnimation(AppMotion.standard) {
                    selectedCellDate = selectedCellDate?.startOfDay == date.startOfDay ? nil : date
                }
            }
    }
    
    // MARK: - 数据处理
    
    private func buildHeatmapWeeks() -> [[Date]] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 周一为一周第一天
        
        let end = Date().startOfDay
        let start = cal.date(byAdding: .day, value: -TendencyConstants.heatmapTrailingDays, to: end) ?? end
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start)) ?? start
        
        return (0..<53).map { weekOffset in
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
            guard let weekStart = week.first else { continue }
            let month = Calendar.current.component(.month, from: weekStart)
            
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
        
        // 添加最后一个月份
        if let currentMonth = currentMonth {
            let span = max(1, weeks.count - currentStart)
            labels.append((offset: currentStart, span: span, title: monthName(for: currentMonth)))
        }
        
        return labels
    }
    
    private func heatLevel(for date: Date) -> Int {
        let day = date.startOfDay
        let count = dailyBillCounts[day, default: 0]
        
        switch count {
        case 0: return 0
        case 1: return 1
        case 2...3: return 2
        case 4...6: return 3
        default: return 4
        }
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
        
        // 未来日期显示为半透明
        return date.startOfDay > Date().startOfDay ? base.opacity(0.35) : base
    }
    
    /// 图例用纯色（不含未来日期透明处理）
    private func heatColor(level: Int) -> Color {
        switch level {
        case 0: return Color(UIColor.systemGray5)
        case 1: return Color(red: 0.79, green: 0.88, blue: 1.0)
        case 2: return Color(red: 0.56, green: 0.75, blue: 0.98)
        case 3: return Color(red: 0.31, green: 0.56, blue: 0.95)
        default: return Color(red: 0.15, green: 0.42, blue: 0.86)
        }
    }
    
    private func monthName(for month: Int) -> String {
        var comps = DateComponents()
        comps.month = month
        let date = Calendar.current.date(from: comps) ?? Date()
        
        return Self.monthFormatter.string(from: date)
    }
}
