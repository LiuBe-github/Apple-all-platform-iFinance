//
//  BudgetCard.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
internal import CoreData

// MARK: - 环形进度条
private struct RingProgressView: View {
    let progress: Double   // 0.0 ~ 1.0
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}

// MARK: - 卡片主体
struct BudgetCardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("monthly_budget_amount") private var monthlyBudget: Double = 0.0
    
    @FetchRequest private var currentMonthBills: FetchedResults<Bill>
    
    init() {
        let calendar = Calendar.current
        let today = Date()
        guard
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)
        else {
            let request: NSFetchRequest<Bill> = Bill.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
            _currentMonthBills = FetchRequest(fetchRequest: request)
            return
        }
        
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = NSPredicate(
            format: "type == %@ AND date >= %@ AND date < %@ AND amount != nil",
            "expenditure",
            startOfMonth as NSDate,
            endOfMonth   as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
        _currentMonthBills = FetchRequest(fetchRequest: request)
    }
    
    // MARK: 计算属性
    private var spent: Double {
        currentMonthBills.reduce(0.0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }
    
    private var remaining: Double { max(monthlyBudget - spent, 0) }
    
    private var progress: Double {
        guard monthlyBudget > 0 else { return 0 }
        return min(spent / monthlyBudget, 1.0)
    }
    
    private var isOverBudget: Bool { spent > monthlyBudget }
    
    /// 动态强调色：安全 → 警告 → 超支
    private var accentColor: Color {
        switch progress {
        case ..<0.6:  return .green
        case ..<0.85: return .orange
        default:       return .red
        }
    }
    
    /// 当前月份中文描述
    private var monthLabel: String {
        let f = DateFormatter()
        f.locale    = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: Date())
    }
    
    // MARK: Body
    var body: some View {
        NavigationLink(destination: BudgetView().toolbar(.hidden, for: .tabBar)) {
            cardContent
        }
        .buttonStyle(.plain)
    }
    
    // MARK: 卡片内容
    private var cardContent: some View {
        HStack(alignment: .center, spacing: 20) {
            
            // ── 左侧：文字信息 ──
            VStack(alignment: .leading, spacing: 0) {
                
                // 月份标签
                Text(monthLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer().frame(height: 6)
                
                // 预算总额
                Text(formatted(monthlyBudget))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                
                Text("月度预算")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Spacer().frame(height: 16)
                
                // 已花 / 剩余 两列
                HStack(spacing: 20) {
                    amountColumn(
                        title: "已花",
                        value: spent,
                        color: accentColor
                    )
                    // 分隔线
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1, height: 32)
                    amountColumn(
                        title: isOverBudget ? "已超支" : "剩余",
                        value: isOverBudget ? spent - monthlyBudget : remaining,
                        color: isOverBudget ? .red : .secondary
                    )
                }
                
                Spacer().frame(height: 14)
                
                // 文字进度条
                progressBar
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // ── 右侧：环形进度 ──
            ZStack {
                RingProgressView(
                    progress: progress,
                    color: accentColor,
                    lineWidth: 8
                )
                .frame(width: 72, height: 72)
                
                VStack(spacing: 1) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("已用")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.07), radius: 12, x: 0, y: 4)
    }
    
    // MARK: 子组件
    private func amountColumn(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatted(value))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
    
    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 5)
                    Capsule()
                        .fill(accentColor)
                        .frame(width: geo.size.width * CGFloat(progress), height: 5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)
                }
            }
            .frame(height: 5)
            
            if isOverBudget {
                Label("已超出预算", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(UIColor.secondarySystemBackground)
            } else {
                Color(UIColor.systemBackground)
            }
        }
    }
    
    // MARK: 金额格式化（中文，带千分位）
    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.maximumFractionDigits = value >= 10_000 ? 0 : 2
        formatter.minimumFractionDigits = value >= 10_000 ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "¥\(value)"
    }
}

// MARK: - 预览
#Preview("正常") {
    BudgetCardView()
        .padding()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("深色") {
    BudgetCardView()
        .padding()
        .preferredColorScheme(.dark)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
