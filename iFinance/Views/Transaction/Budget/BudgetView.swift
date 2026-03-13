//
//  BudgetView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI
internal import CoreData

// MARK: - BudgetView
struct BudgetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    @FetchRequest private var currentMonthExpenditures: FetchedResults<Bill>
    @AppStorage("monthly_budget_amount") private var monthlyBudget: Double = 3000.0
    
    // 修改预算相关状态
    @State private var isEditingBudget = false
    @State private var budgetInput = ""
    @FocusState private var isBudgetFieldFocused: Bool
    
    init() {
        let calendar = Calendar.current
        let today = Date()
        guard
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)
        else {
            let req: NSFetchRequest<Bill> = Bill.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
            _currentMonthExpenditures = FetchRequest(fetchRequest: req)
            return
        }
        let req: NSFetchRequest<Bill> = Bill.fetchRequest()
        req.predicate = NSPredicate(
            format: "type == %@ AND date >= %@ AND date < %@ AND amount != nil AND category != NULL",
            "expenditure", startOfMonth as NSDate, endOfMonth as NSDate
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
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                
                if categoryItems.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    categoryList
                        .padding(.horizontal, 16)
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
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                        Text("budget.adjust")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
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
        VStack(spacing: 20) {
            
            // ── 月份 + 预算总额 ──
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
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
                        .animation(.spring(response: 0.55, dampingFraction: 0.8), value: progress)
                    
                    VStack(spacing: 1) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("budget.used")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 68, height: 68)
            }
            
            // ── 细进度条 ──
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.1)).frame(height: 6)
                        Capsule()
                            .fill(accentColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 6)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Label(
                        isOver ? String(format: String(localized: "budget.over_amount"), formatAmount(totalExpenditure - monthlyBudget))
                        : String(format: String(localized: "budget.spent_amount"), formatAmount(totalExpenditure)),
                        systemImage: isOver ? "exclamationmark.triangle.fill" : "arrow.up.right"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isOver ? .red : .secondary)
                    
                    Spacer()
                    
                    Text(isOver ? String(localized: "budget.over") : String(format: String(localized: "budget.remaining_amount"), formatAmount(remaining)))
                        .font(.caption)
                        .foregroundStyle(isOver ? .red : .secondary)
                }
            }
            
            // ── 三格统计栏 ──
            HStack(spacing: 0) {
                statCell(title: String(localized: "budget.spent"), value: formatAmount(totalExpenditure), color: accentColor)
                divider
                statCell(title: isOver ? String(localized: "budget.over") : String(localized: "budget.remaining"),
                         value: formatAmount(isOver ? totalExpenditure - monthlyBudget : remaining),
                         color: isOver ? .red : .primary)
                divider
                statCell(title: String(localized: "budget.count"),
                         value: String(format: String(localized: "budget.count_value"), currentMonthExpenditures.count),
                         color: .primary)
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            // 标题行
            HStack {
                Text("budget.categories")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: String(localized: "budget.categories_count"), categoryItems.count))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
            
            // 分类卡片
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 12) {
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
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = .autoupdatingCurrent
        f.maximumFractionDigits = value >= 10_000 ? 0 : 2
        f.minimumFractionDigits = value >= 10_000 ? 0 : 2
        return f.string(from: NSNumber(value: value)) ?? "¥\(value)"
    }
    
    // MARK: - 预算编辑 Sheet
    private var budgetEditSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 当前预算显示
                VStack(spacing: 8) {
                    Text("budget.current_monthly")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(monthlyBudget))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .padding(.top, 32)
                .padding(.bottom, 40)
                
                // 输入区域
                VStack(alignment: .leading, spacing: 12) {
                    Text("budget.new_amount")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Text("¥")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("", text: $budgetInput)
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .focused($isBudgetFieldFocused)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                    
                    // 快捷金额按钮
                    VStack(spacing: 10) {
                        Text("budget.quick_set")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            quickAmountButton(1000)
                            quickAmountButton(3000)
                            quickAmountButton(5000)
                            quickAmountButton(8000)
                            quickAmountButton(10000)
                            quickAmountButton(15000)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 保存按钮
                Button {
                    saveBudget()
                } label: {
                    Text("common.save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isValidInput ? Color.blue : Color.gray.opacity(0.3))
                        )
                }
                .disabled(!isValidInput)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            monthlyBudget = newValue
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
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = .autoupdatingCurrent
        f.maximumFractionDigits = v >= 10_000 ? 0 : 2
        f.minimumFractionDigits = v >= 10_000 ? 0 : 2
        return f.string(from: NSNumber(value: v)) ?? "¥\(v)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                
                // 图标圆圈
                ZStack {
                    Circle()
                        .fill(barColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: category.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(barColor)
                }
                
                // 中间：分类名 + 进度条
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(category.localizedDisplayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatAmount(amount))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    
                    HStack(spacing: 8) {
                        // 进度条
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.10))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(barColor)
                                    .frame(width: geo.size.width * CGFloat(percentage), height: 4)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: percentage)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            
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
}

#Preview("深色模式") {
    NavigationStack {
        BudgetView()
    }
    .preferredColorScheme(.dark)
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
