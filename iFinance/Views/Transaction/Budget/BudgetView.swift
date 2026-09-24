//
//  BudgetView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI
import Charts
internal import CoreData

// MARK: - BudgetView
struct BudgetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthManager
    
    @FetchRequest private var currentMonthExpenditures: FetchedResults<Bill>
    
    private var monthlyBudget: Double {
        authManager.monthlyBudget
    }
    
    // MARK: - 静态格式化器
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = .autoupdatingCurrent
        return f
    }()
    
    // 修改预算相关状态
    @State private var isEditingBudget = false
    @State private var budgetInput = ""
    @FocusState private var isBudgetFieldFocused: Bool
    
    // 图表切换状态
    @State private var chartType: CategoryChartType = .list
    // 饼图选中角度（chartAngleSelection）与选中分类
    @State private var selectedPieAngle: Double?
    @State private var selectedPieCategory: ExpenditureCategory?
    
    enum CategoryChartType: String, CaseIterable {
        case list = "列表"
        case pie = "饼图"

        var displayName: String {
            switch self {
            case .list: return L10n.string("budget.chart_type")
            case .pie: return L10n.string("chart.type_pie")
            }
        }
    }
    
    init() {
        let calendar = Calendar.current
        let today = Date()
        guard
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)
        else {
            let req: NSFetchRequest<Bill> = Bill.fetchRequest()
            req.predicate = PersistenceController.billUserPredicate
            req.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
            _currentMonthExpenditures = FetchRequest(fetchRequest: req)
            return
        }
        let req: NSFetchRequest<Bill> = Bill.fetchRequest()
        req.predicate = NSPredicate(
            format: "type == %@ AND date >= %@ AND date < %@ AND amount != nil AND category != NULL AND createdBy == %@",
            "expenditure", startOfMonth as NSDate, endOfMonth as NSDate, PersistenceController.currentUserIdentifier
        )
        req.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
        _currentMonthExpenditures = FetchRequest(fetchRequest: req)
    }
    
    // MARK: 计算属性
    private var totalExpenditure: Double {
        currentMonthExpenditures.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }
    
    private var remaining: Double {
        max(monthlyBudget - totalExpenditure, 0)
    }
    private var progress: Double {
        monthlyBudget > 0 ? min(totalExpenditure / monthlyBudget, 1) : 0
    }
    private var isOver: Bool {
        totalExpenditure > monthlyBudget
    }
    
    private var accentColor: Color {
        switch progress {
        case ..<0.6: return Color(red: 0.18, green: 0.78, blue: 0.44)  // 绿
        case ..<0.85: return Color(red: 1.0, green: 0.62, blue: 0.0)   // 橙
        default: return Color(red: 1.0, green: 0.27, blue: 0.23)  // 红
        }
    }
    
    private var categoryItems: [(category: ExpenditureCategory, amount: Double)] {
        var dict: [ExpenditureCategory: Double] = [:]
        for bill in currentMonthExpenditures {
            guard let raw = bill.category,
                  let cat = ExpenditureCategory(rawValue: raw),
                  let amt = bill.amount?.doubleValue else { continue }
            dict[cat, default: 0] += amt
        }
        return ExpenditureCategory.allCases
            .map { (category: $0, amount: dict[$0] ?? 0) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }
    
    private var monthLabel: String {
        Date().formatted(.dateTime.year().month(.wide))
    }
    
    // MARK: Body
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                summaryHeader
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.section)
                
                if categoryItems.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    categoryList
                        .padding(.horizontal, AppSpacing.lg)
                }
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("budget.title")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    budgetInput = String(format: "%.0f", monthlyBudget)
                    isEditingBudget = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                        Text("budget.adjust")
                            .font(AppTypography.secondary.weight(.medium))
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .foregroundStyle(.blue)
                }
            }
        }
        .sheet(isPresented: $isEditingBudget) {
            budgetEditSheet
        }
    }
    
    // MARK: - 顶部 Summary
    private var summaryHeader: some View {
        VStack(spacing: AppSpacing.xl) {
            
            // ── 月份 + 预算总额 ──
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(monthLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(monthlyBudget))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("budget.monthly_limit")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                
                // 环形指示
                ZStack {
                    Circle()
                        .stroke(accentColor.opacity(0.12), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(accentColor,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .appAnimation(AppMotion.emphasized, value: progress)
                    
                    VStack(spacing: 1) {
                        Text(AppNumberFormat.percent(progress))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("budget.used")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 68, height: 68)
            }
            
            // ── 细进度条 ──
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.1)).frame(height: 6)
                        Capsule()
                            .fill(accentColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 6)
                            .appAnimation(AppMotion.standard, value: progress)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Label(
                        isOver ? String(format: L10n.string("budget.over_amount"), formatAmount(totalExpenditure - monthlyBudget))
                        : String(format: L10n.string("budget.spent_amount"), formatAmount(totalExpenditure)),
                        systemImage: isOver ? "exclamationmark.triangle.fill" : "arrow.up.right"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isOver ? .red : .secondary)
                    
                    Spacer()
                    
                    Text(isOver ? L10n.string("budget.over") : String(format: L10n.string("budget.remaining_amount"), formatAmount(remaining)))
                        .font(.caption)
                        .foregroundStyle(isOver ? .red : .secondary)
                }
            }
            
            // ── 三格统计栏 ──
            HStack(spacing: 0) {
                statCell(title: L10n.string("budget.spent"), value: formatAmount(totalExpenditure), color: accentColor)
                divider
                statCell(title: isOver ? L10n.string("budget.over") : L10n.string("budget.remaining"),
                         value: formatAmount(isOver ? totalExpenditure - monthlyBudget : remaining),
                         color: isOver ? .red : .primary)
                divider
                statCell(title: L10n.string("budget.count"),
                         value: String(format: L10n.string("budget.count_value"), currentMonthExpenditures.count),
                         color: .primary)
            }
            .padding(.vertical, AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 1, height: 32)
    }
    
    private func statCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 分类列表
    private var categoryList: some View {
        VStack(spacing: 0) {
            // 标题行 + 切换器
            HStack {
                Text("budget.categories")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: L10n.string("budget.categories_count"), categoryItems.count))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                // 图表类型切换
                Picker("budget.chart_type", selection: $chartType) {
                    ForEach(CategoryChartType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.bottom, AppSpacing.md)
            
            // 根据选择显示列表或饼图
            if chartType == .pie {
                pieChartView
            } else {
                categoryListContent
            }
        }
    }
    
    // MARK: - 分类列表内容
    private var categoryListContent: some View {
        VStack(spacing: 1) {
            ForEach(Array(categoryItems.enumerated()), id: \.element.category) { index, item in
                CategoryRowView(
                    category: item.category,
                    amount: item.amount,
                    total: totalExpenditure,
                    isLast: index == categoryItems.count - 1
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
    
    // MARK: - 饼状图视图
    private var pieChartView: some View {
        VStack(spacing: AppSpacing.lg) {
            // 饼图
            Chart(categoryItems, id: \.category) { item in
                SectorMark(
                    angle: .value(L10n.string("bill.amount_legend"), item.amount),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value(L10n.string("bill.category_legend"), item.category.localizedDisplayName))
                .cornerRadius(4)
                .opacity(selectedPieAngle == nil || selectedPieCategory == item.category ? 1 : 0.4)
            }
            .chartLegend(position: .bottom, alignment: .center, spacing: AppSpacing.md)
            .chartAngleSelection(value: $selectedPieAngle)
            .onChange(of: selectedPieAngle) { _, newAngle in
                HapticManager.shared.selectionChanged()
                selectedPieCategory = newAngle.map { pieCategory(at: $0) } ?? nil
            }
            .chartBackground { proxy in
                // 中心选中提示
                if let cat = selectedPieCategory,
                   let amount = categoryItems.first(where: { $0.category == cat })?.amount {
                    VStack(spacing: 2) {
                        Text(cat.localizedDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatAmount(amount))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .appNumericTransition(value: amount)
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .appAnimation(AppMotion.quick, value: cat)
                }
            }
            .frame(height: AppLayout.chartHeightRegular + 50)
            .padding(.horizontal, AppSpacing.sm)
            .appAnimation(AppMotion.quick, value: selectedPieCategory)
            
            // 分类金额列表
            VStack(spacing: 1) {
                ForEach(Array(categoryItems.enumerated()), id: \.element.category) { index, item in
                    HStack(spacing: AppSpacing.md) {
                        // 颜色指示
                        Circle()
                            .fill(colorForCategory(item.category))
                            .frame(width: 10, height: 10)
                        
                        Text(item.category.localizedDisplayName)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(formatAmount(item.amount))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .appNumericTransition(value: item.amount)
                        
                        Text("\(Int(item.amount / totalExpenditure * 100))%")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .contentShape(Rectangle())
                    .background(
                        selectedPieCategory == item.category
                        ? Color.blue.opacity(0.06)
                        : Color.clear
                    )
                    .onTapGesture {
                        HapticManager.shared.selectionChanged()
                        withAnimation(AppMotion.quick) {
                            if selectedPieCategory == item.category {
                                selectedPieCategory = nil
                                selectedPieAngle = nil
                            } else {
                                selectedPieCategory = item.category
                            }
                        }
                    }
                    
                    if index < categoryItems.count - 1 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.08))
                            .frame(height: 0.5)
                            .padding(.leading, 38)
                    }
                }
            }
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
        .padding(.horizontal, AppSpacing.xs)
    }
    
    /// 根据角度解析对应的分类（饼图扇区）
    private func pieCategory(at angle: Double) -> ExpenditureCategory? {
        let total = categoryItems.reduce(0.0) { $0 + $1.amount }
        guard total > 0 else { return nil }
        var accumulated: Double = 0
        for item in categoryItems {
            accumulated += item.amount
            if angle <= accumulated / total * 360 {
                return item.category
            }
        }
        return nil
    }
    
    // 分类颜色
    private static let palette: [Color] = [
        Color(red: 0.18, green: 0.60, blue: 1.0),
        Color(red: 0.30, green: 0.78, blue: 0.44),
        Color(red: 1.0,  green: 0.60, blue: 0.10),
        Color(red: 0.75, green: 0.35, blue: 1.0),
        Color(red: 1.0,  green: 0.30, blue: 0.30),
        Color(red: 0.10, green: 0.75, blue: 0.85),
        Color(red: 1.0,  green: 0.80, blue: 0.10),
        Color(red: 0.55, green: 0.55, blue: 0.60),
    ]
    
    private func colorForCategory(_ category: ExpenditureCategory) -> Color {
        let idx = (ExpenditureCategory.allCases.firstIndex(of: category) ?? 0)
        return Self.palette[idx % Self.palette.count]
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("budget.empty")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: 金额格式化
    private func formatAmount(_ value: Double) -> String {
        Self.currencyFormatter.maximumFractionDigits = value >= 10_000 ? 0 : 2
        Self.currencyFormatter.minimumFractionDigits = value >= 10_000 ? 0 : 2
        return Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "¥\(value)"
    }
    
    // MARK: - 预算编辑 Sheet
    private var budgetEditSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 当前预算显示
                VStack(spacing: AppSpacing.sm) {
                    Text("budget.current_monthly")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(monthlyBudget))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .padding(.top, AppSpacing.section)
                .padding(.bottom, 40)
                
                // 输入区域
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("budget.new_amount")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: AppSpacing.sm) {
                        Text("¥")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("", text: $budgetInput)
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .focused($isBudgetFieldFocused)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 快捷金额按钮
                    VStack(spacing: AppSpacing.md) {
                        Text("budget.quick_set")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: AppSpacing.md) {
                            quickAmountButton(1000)
                            quickAmountButton(3000)
                            quickAmountButton(5000)
                            quickAmountButton(8000)
                            quickAmountButton(10000)
                            quickAmountButton(15000)
                        }
                    }
                    .padding(.top, AppSpacing.md)
                }
                .padding(.horizontal, AppSpacing.xl)
                
                Spacer()
                
                // 保存按钮
                Button {
                    saveBudget()
                } label: {
                    Text("common.save")
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                                .fill(isValidInput ? Color.blue : Color.gray.opacity(0.3))
                        )
                }
                .disabled(!isValidInput)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("budget.adjust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("auth.cancel") {
                        isEditingBudget = false
                    }
                }
            }
            .onAppear {
                isBudgetFieldFocused = true
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // 快捷金额按钮
    private func quickAmountButton(_ amount: Double) -> some View {
        Button {
            budgetInput = String(format: "%.0f", amount)
        } label: {
            Text(formatAmount(amount))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
        }
    }
    
    // 验证输入是否有效
    private var isValidInput: Bool {
        guard let value = Double(budgetInput), value > 0, value <= 1_000_000 else {
            return false
        }
        return true
    }
    
    // 保存预算
    private func saveBudget() {
        guard let newValue = Double(budgetInput), newValue > 0 else { return }
        
        withAnimation(AppMotion.standard) {
            authManager.updateMonthlyBudget(newValue)
        }
        
        // 触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        isEditingBudget = false
    }
}

// MARK: - 分类行
struct CategoryRowView: View {
    let category:  ExpenditureCategory
    let amount:    Double
    let total:     Double
    let isLast:    Bool
    
    // MARK: - 静态格式化器
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = .autoupdatingCurrent
        return f
    }()
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return amount / total
    }
    
    // 给每个分类一个固定的色调（基于 index，循环取色）
    private static let palette: [Color] = [
        Color(red: 0.18, green: 0.60, blue: 1.0),
        Color(red: 0.30, green: 0.78, blue: 0.44),
        Color(red: 1.0,  green: 0.60, blue: 0.10),
        Color(red: 0.75, green: 0.35, blue: 1.0),
        Color(red: 1.0,  green: 0.30, blue: 0.30),
        Color(red: 0.10, green: 0.75, blue: 0.85),
        Color(red: 1.0,  green: 0.80, blue: 0.10),
        Color(red: 0.55, green: 0.55, blue: 0.60),
    ]
    
    private var barColor: Color {
        let idx = (ExpenditureCategory.allCases.firstIndex(of: category) ?? 0)
        return Self.palette[idx % Self.palette.count]
    }
    
    private func formatAmount(_ v: Double) -> String {
        Self.currencyFormatter.maximumFractionDigits = v >= 10_000 ? 0 : 2
        Self.currencyFormatter.minimumFractionDigits = v >= 10_000 ? 0 : 2
        return Self.currencyFormatter.string(from: NSNumber(value: v)) ?? "¥\(v)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                
                // 图标圆圈
                ZStack {
                    Circle()
                        .fill(barColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: category.icon)
                        .font(AppTypography.secondary.weight(.medium))
                        .foregroundStyle(barColor)
                }
                
                // 中间：分类名 + 进度条
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(category.localizedDisplayName)
                            .font(AppTypography.secondary.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatAmount(amount))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    
                    HStack(spacing: AppSpacing.sm) {
                        // 进度条
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.10))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(barColor)
                                    .frame(width: geo.size.width * CGFloat(percentage), height: 4)
                                    .appAnimation(AppMotion.standard, value: percentage)
                            }
                        }
                        .frame(height: 4)
                        
                        // 百分比
                        Text("\(Int((percentage * 100).rounded()))%")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
            
            // 分隔线（最后一行不显示）
            if !isLast {
                Rectangle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 0.5)
                    .padding(.leading, 66)
            }
        }
    }
}

// MARK: - 预览
#Preview {
    NavigationStack {
        BudgetView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(AuthManager.shared)
}

#Preview("深色模式") {
    NavigationStack {
        BudgetView()
    }
    .preferredColorScheme(.dark)
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(AuthManager.shared)
}
