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

    var displayName: String {
        switch self {
        case .today: return L10n.string("bill.time_range.today")
        case .thisWeek: return L10n.string("bill.time_range.week")
        case .thisMonth: return L10n.string("bill.time_range.month")
        case .thisYear: return L10n.string("bill.time_range.year")
        }
    }
}

struct BillsCardView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        predicate: PersistenceController.billUserPredicate,
        animation: .default
    ) private var bills: FetchedResults<Bill>

    @State private var selectedTimeRange: TimeRange = .thisMonth
    /// 收到 `.billDidChange` 后自增，用于强制重算当日结余等派生值
    @State private var billRefreshToken = 0
    var selectedCategory: Binding<String?>?
    var selectedNote: Binding<String?>?

    // MARK: - 按时间范围、类别、备注过滤
    private var filteredBills: [Bill] {
        let range = selectedTimeRange.dateRange
        let catValue = selectedCategory?.wrappedValue
        let noteValue = selectedNote?.wrappedValue
        return bills.filter { bill in
            guard let date = bill.date else { return false }
            let inTimeRange = date >= range.start && date <= range.end
            let inCategory: Bool
            if let cat = catValue {
                inCategory = bill.category == cat
            } else {
                inCategory = true
            }
            let inNote: Bool
            if let note = noteValue {
                inNote = bill.note == note
            } else {
                inNote = true
            }
            return inTimeRange && inCategory && inNote
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
        // 每次渲染只做一次过滤 + 分组（原先 body 内引用两次会导致重复计算）
        let groups = groupedBills
        // 读取刷新令牌：让「账单保存成功」能强制走一次 body（当日结余因此必定重算）
        let _ = billRefreshToken
        return VStack(spacing: AppSpacing.md) {
            // 时间范围选择器
            timeRangePicker
            
            // 账单列表
            Group {
                if groups.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(groups, id: \.date) { group in
                            DayGroupCard(
                                date: group.date,
                                bills: group.bills,
                                refreshRevision: billRefreshToken
                            )
                        }
                    }
                }
            }
            .id(selectedTimeRange)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .appAnimation(AppMotion.standard, value: selectedTimeRange)
        }
        .onReceive(NotificationCenter.default.publisher(for: .billDidChange)) { _ in
            billRefreshToken &+= 1
        }
    }
    
    // MARK: - 时间范围选择器
    private var timeRangePicker: some View {
        Picker("bill.time_range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .onChange(of: selectedTimeRange) { _, _ in
            HapticManager.shared.selectionChanged()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolEffect(.bounce, value: selectedTimeRange)
            Text("bill.empty")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .appGlassCard(cornerRadius: AppRadius.card)
    }
}

// MARK: - 单日分组卡片
private struct DayGroupCard: View {
    let date:  Date
    let bills: [Bill]
    /// 实体数组里的对象身份不会因字段编辑而改变；显式版本可让金额与当日净额重新求值。
    let refreshRevision: Int

    @State private var appeared = false

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = Locale(identifier: "zh_CN")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    // 说明：这里曾经实现过自定义 `Equatable` 用来「按内容判断是否重算 dayNet」，
    // 但两侧数组持有的是同一批 NSManagedObject / @Model 实例，比较时读到的都是**当前值**，
    // 永远相等——金额被编辑后 SwiftUI 会跳过重绘（当日净额与列表不刷新）。
    // 已改为交给 SwiftUI 默认的重绘规则（视图值不含 Equatable 时按身份重绘）。

    private var sortedBills: [Bill] {
        bills.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }
    
    /// 当日净额：收入为正、支出为负、**转账不计入**。
    /// 走 `BillMath` 统一口径（兼容历史中文类型，别再直接比 `bill.type == "expenditure"`）。
    private var dayNet: Double {
        bills.reduce(0.0) { total, bill in
            total + BillMath.signedAmount(type: bill.type, amount: bill.amount?.doubleValue ?? 0)
        }
    }
    
    private var dayNetColor: Color {
        dayNet >= 0
        ? Color(red: 0.18, green: 0.78, blue: 0.44)
        : Color(red: 1.0,  green: 0.27, blue: 0.23)
    }
    
    private var dayNetLabel: String {
        let abs = Swift.abs(dayNet)
        let str = Self.amountFormatter.string(from: NSNumber(value: abs)) ?? "¥\(abs)"
        return dayNet >= 0 ? "+\(str)" : "-\(str)"
    }
    
    var body: some View {
        // 将刷新版本作为本视图的明确输入，避免 SwiftUI 因 bills 仍是同一批实体而跳过更新。
        let _ = refreshRevision
        VStack(spacing: 0) {
            // ── 日期头部 ──
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(dayLabel)
                        .font(AppTypography.secondary.weight(.semibold))
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
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            
            // 分隔线
            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 0.5)
                .padding(.leading, AppSpacing.lg)
            
            // ── 账单行 ──
            VStack(spacing: 0) {
                ForEach(Array(sortedBills.enumerated()), id: \.element.objectID) { index, bill in
                    NavigationLink(
                        destination: EditBillView(bill: bill)
                            .id(bill.updatedAt ?? .distantPast)   // 保存后身份变化 → 下次进入重新初始化表单，不用旧 @State
                            .toolbar(.hidden, for: .tabBar)
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
        .appGlassCard(cornerRadius: AppRadius.card)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(AppMotion.standard) {
                appeared = true
            }
        }
    }
    
    // MARK: 日期格式
    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return L10n.string("common.today") }
        if cal.isDateInYesterday(date) { return L10n.string("common.yesterday") }
        
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
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
    }
    .background(Color(UIColor.systemGroupedBackground))
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
