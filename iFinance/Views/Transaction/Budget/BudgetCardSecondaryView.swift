//
//  BudgetCardSecondaryView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

// MARK: This file has been deprecated.
import SwiftUI
internal import CoreData

struct BudgetCardSecondaryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // 示例数据（实际项目中应从 ViewModel 或 State 获取）
    @AppStorage("monthly_budget_amount") private var monthlyBudget: Double = 3000.0 // MARK: 此预算金额需要用CoreData做持久化
    
    var body: some View {
        NavigationLink(
            destination: EditBudgetView(budget: $monthlyBudget)
                .toolbar(.hidden, for: .tabBar)
        ) {
            VStack(alignment: .leading, spacing: 9) {
                // 标题
                Text("budget.monthly_limit")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                // 预算总额
                Text("¥\(monthlyBudget, specifier: "%.2f")")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                // 标题
                Text("budget.tap_to_edit")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green,
                                Color.orange,
                                Color.blue
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(radius: 3)
        }
        .buttonStyle(PlainButtonStyle()) // 去除按钮默认样式，保持视觉一致
    }
}

#Preview {
    BudgetCardSecondaryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
