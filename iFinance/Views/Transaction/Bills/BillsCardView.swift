//
//  BillsCard.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/12.
//

import SwiftUI
internal import CoreData

// MARK: - 时间范围枚举
enum TimeRange: String, CaseIterable {
    case today = "本日"
    case thisWeek = "本周"
    case thisMonth = "本月"
    case thisYear = "本年"
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (start, now)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (start, now)
        case .thisYear:
            let start = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (start, now)
        }
    }
}

struct BillsCardView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        animation: .default
    ) private var bills: FetchedResults<Bill>
    
    @State private var selectedTimeRange: TimeRange = .thisMonth
    
    // MARK: - 按时间范围过滤
    private var filteredBills: [Bill] {
        let range = selectedTimeRange.dateRange
        return bills.filter { bill in
            guard let date = bill.date else { return false }
            return date >= range.start && date <= range.end
        }
    }
    
    // MARK: - 按日分组
    private var groupedBills: [(date: Date, bills: [Bill])] {
        guard !filteredBills.isEmpty else { return [] }
        let grouped = Dictionary(grouping: filteredBills) { bill in
            Calendar.current.startOfDay(for: bill.date ?? Date())
        }
        return grouped.sorted { $0.key > $1.key }.map { ($0.key, $0.value) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 时间范围选择器
            timeRangePicker
            
            // 账单列表
            if groupedBills.isEmpty {
                emptyState
            } else {
                ForEach(groupedBills, id: \.date) { group in
                    DayGroupCard(date: group.date, bills: group.bills)
                }
            }
        }
    }
    
    // MARK: - 时间范围选择器
    private var timeRangePicker: some View {
        Picker("时间范围", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("bill.empty")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - 单日分组卡片
private struct DayGroupCard: View {
    let date:  Date
    let bills: [Bill]
    
    private var sortedBills: [Bill] {
        bills.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }
    
    /// 当日净额：收入为正，支出为负
    private var dayNet: Double {
        bills.reduce(0.0) { total, bill in
            let amt = bill.amount?.doubleValue ?? 0
            return bill.type == "expenditure" ? total - amt : total + amt
        }
    }
    
    private var dayNetColor: Color {
        dayNet >= 0
        ? Color(red: 0.18, green: 0.78, blue: 0.44)
        : Color(red: 1.0,  green: 0.27, blue: 0.23)
    }
    
    private var dayNetLabel: String {
        let abs = Swift.abs(dayNet)
        let f = NumberFormatter()
        f.numberStyle           = .currency
        f.currencySymbol        = "¥"
        f.locale                = Locale(identifier: "zh_CN")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        let str = f.string(from: NSNumber(value: abs)) ?? "¥\(abs)"
        return dayNet >= 0 ? "+\(str)" : "-\(str)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── 日期头部 ──
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(dayLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(weekdayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(dayNetLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(dayNetColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 分隔线
            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 0.5)
                .padding(.leading, 16)
            
            // ── 账单行 ──
            VStack(spacing: 0) {
                ForEach(Array(sortedBills.enumerated()), id: \.element.objectID) { index, bill in
                    NavigationLink(
                        destination: EditBillView(bill: bill).toolbar(.hidden, for: .tabBar)
                    ) {
                        TransactionRowView(bill: bill)
                    }
                    .buttonStyle(.plain)
                    
                    if index < sortedBills.count - 1 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 62)  // 与图标右边缘对齐
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: 日期格式
    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return String(localized: "common.today") }
        if cal.isDateInYesterday(date) { return String(localized: "common.yesterday") }
        
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
    
    private var weekdayLabel: String {
        // 今天/昨天不再重复显示星期
        let cal = Calendar.current
        if cal.isDateInToday(date) || cal.isDateInYesterday(date) {
            return date.formatted(.dateTime.month(.abbreviated).day().weekday(.wide))
        }
        return date.formatted(.dateTime.weekday(.wide))
    }
}

// MARK: - 预览
#Preview {
    ScrollView {
        BillsCardView()
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }
    .background(Color(UIColor.systemGroupedBackground))
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
