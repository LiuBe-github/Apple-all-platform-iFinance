//
//  BudgetCard.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
import SwiftData

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
                .appAnimation(AppMotion.emphasized, value: progress)
        }
    }
}

// MARK: - 卡片主体
struct BudgetCardView: View {
    @Environment(\.modelContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthManager

    // 预算从 AuthManager 获取（与 BudgetView 保持一致）
    private var monthlyBudget: Double {
        authManager.monthlyBudget
    }

    @Query(filter: PersistenceController.billUserPredicate, sort: \Bill.date, order: .reverse)
    private var allUserBills: [Bill]

    /// 本月支出账单（SwiftData 版：内存过滤 type / date / amount）
    private var currentMonthBills: [Bill] {
        let calendar = Calendar.current
        let today = Date()
        guard
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)
        else { return [] }

        return allUserBills.filter { bill in
            guard bill.type == "expenditure", bill.amount != nil, let date = bill.date else { return false }
            return date >= startOfMonth && date < endOfMonth
        }
    }

    // MARK: - 静态 NumberFormatter（避免每次渲染都新建）
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = .autoupdatingCurrent
        return f
    }()
    
    // MARK: 计算属性
    private var spent: Double {
        currentMonthBills.reduce(0.0) { $0 + ($1.amountDouble) }
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
        Date().formatted(.dateTime.year().month(.wide))
    }
    
    // MARK: Body
    var body: some View {
        NavigationLink(destination: BudgetView().toolbar(.hidden, for: .tabBar)) {
            cardContent
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.98))
    }
    
    // MARK: 卡片内容
    private var cardContent: some View {
        HStack(alignment: .center, spacing: AppSpacing.xl) {
            
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
                    .appNumericTransition(value: monthlyBudget)
                
                Text("budget.monthly_limit")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Spacer().frame(height: 16)
                
                // 已花 / 剩余 两列
                HStack(spacing: AppSpacing.xl) {
                    amountColumn(
                        title: L10n.string("budget.spent"),
                        value: spent,
                        color: accentColor
                    )
                    // 分隔线
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1, height: 32)
                    amountColumn(
                        title: isOverBudget ? L10n.string("budget.over") : L10n.string("budget.remaining"),
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
                        .appNumericTransition(value: progress * 100)
                    Text("budget.used")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.xl)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sheet, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sheet, style: .continuous)
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
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 5)
                    Capsule()
                        .fill(accentColor)
                        .frame(width: geo.size.width * CGFloat(progress), height: 5)
                        .appAnimation(AppMotion.standard, value: progress)
                }
            }
            .frame(height: 5)
            
            if isOverBudget {
                Label("budget.exceeded", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating, value: isOverBudget)
                    .transition(.move(edge: .top).combined(with: .opacity))
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
        Self.currencyFormatter.maximumFractionDigits = value >= 10_000 ? 0 : 2
        Self.currencyFormatter.minimumFractionDigits = value >= 10_000 ? 0 : 2
        return Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "¥\(value)"
    }
}

// MARK: - 预览
#Preview("正常") {
    BudgetCardView()
        .padding()
        .environment(\.modelContext, PersistenceController.preview.container.viewContext)
}

#Preview("深色") {
    BudgetCardView()
        .padding()
        .preferredColorScheme(.dark)
        .environment(\.modelContext, PersistenceController.preview.container.viewContext)
}
