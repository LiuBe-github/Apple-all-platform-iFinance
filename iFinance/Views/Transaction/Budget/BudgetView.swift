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
    
    init() {
        let calendar = Calendar.current
        let today = Date()
        guard
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let endOfMonth   = calendar.date(byAdding: .month, value: 1, to: startOfMonth)
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
    
    private var remaining: Double { max(monthlyBudget - totalExpenditure, 0) }
    private var progress: Double  { monthlyBudget > 0 ? min(totalExpenditure / monthlyBudget, 1) : 0 }
    private var isOver: Bool      { totalExpenditure > monthlyBudget }
    
    private var accentColor: Color {
        switch progress {
        case ..<0.6:  return Color(red: 0.18, green: 0.78, blue: 0.44)  // 绿
        case ..<0.85: return Color(red: 1.0,  green: 0.62, blue: 0.0)   // 橙
        default:      return Color(red: 1.0,  green: 0.27, blue: 0.23)  // 红
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
        let f = DateFormatter()
        f.locale    = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: Date())
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
        .navigationTitle("预算")
        .navigationBarTitleDisplayMode(.large)
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
                    Text("月度预算上限")
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
                        Text("已用")
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
                        isOver ? "已超支 \(formatAmount(totalExpenditure - monthlyBudget))"
                        : "已花 \(formatAmount(totalExpenditure))",
                        systemImage: isOver ? "exclamationmark.triangle.fill" : "arrow.up.right"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isOver ? .red : .secondary)
                    
                    Spacer()
                    
                    Text(isOver ? "超支" : "剩余 \(formatAmount(remaining))")
                        .font(.caption)
                        .foregroundStyle(isOver ? .red : .secondary)
                }
            }
            
            // ── 三格统计栏 ──
            HStack(spacing: 0) {
                statCell(title: "已花", value: formatAmount(totalExpenditure), color: accentColor)
                divider
                statCell(title: isOver ? "超支" : "剩余",
                         value: formatAmount(isOver ? totalExpenditure - monthlyBudget : remaining),
                         color: isOver ? .red : .primary)
                divider
                statCell(title: "笔数",
                         value: "\(currentMonthExpenditures.count)笔",
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
                Text("支出分类")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text("共 \(categoryItems.count) 项")
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
            Text("本月暂无支出记录")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: 金额格式化
    private func formatAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle            = .currency
        f.currencySymbol         = "¥"
        f.locale                 = Locale(identifier: "zh_CN")
        f.maximumFractionDigits  = value >= 10_000 ? 0 : 2
        f.minimumFractionDigits  = value >= 10_000 ? 0 : 2
        return f.string(from: NSNumber(value: value)) ?? "¥\(value)"
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
        f.numberStyle           = .currency
        f.currencySymbol        = "¥"
        f.locale                = Locale(identifier: "zh_CN")
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
                        Text(category.rawValue)
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
