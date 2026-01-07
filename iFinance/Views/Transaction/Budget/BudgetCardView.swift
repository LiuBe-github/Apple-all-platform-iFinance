//
//  BudgetCard.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
internal import CoreData

struct BudgetCardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        animation: .default
    ) private var bills: FetchedResults<Bill>
    
    // 示例数据（实际项目中应从 ViewModel 或 State 获取）
    @State private var monthlyBudget: Double = 3000.0 // MARK: 此预算金额需要用CoreData做持久化
    
    // 自动获取当前月份的所有支出账单
    @FetchRequest private var currentMonthBills: FetchedResults<Bill>
    
    init() {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            // fallback 初始化（也必须有 sortDescriptors！）
            let request: NSFetchRequest<Bill> = Bill.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
            _currentMonthBills = FetchRequest(fetchRequest: request)
            return
        }
        
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = NSPredicate(format: """
            type == %@ AND 
            date >= %@ AND 
            date < %@ AND 
            amount != nil
            """,
                                        "expenditure",
                                        startOfMonth as NSDate,
                                        endOfMonth as NSDate
        )
        
        // 🔥 关键修复：添加排序描述符
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
        _currentMonthBills = FetchRequest(fetchRequest: request)
    }
    
    // 计算本月支出总和（只读）
    private var spentThisMonth: Double { // MARK: 本月已花，封装一个函数，计算指定月份的支出总和
        currentMonthBills.reduce(0.0) { sum, bill in
            sum + (bill.amount?.doubleValue ?? 0.0)
        }
    }
    
    var body: some View {
        NavigationLink(
            destination: EditBudgetView(budget: $monthlyBudget)
                .toolbar(.hidden, for: .tabBar)
        ) {
            VStack(alignment: .leading, spacing: 9) {
                // 标题
                Text("MONTHLY BUDGET")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                // 预算总额
                Text("¥\(monthlyBudget, specifier: "%.2f")")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // 进度信息
                VStack(alignment: .leading, spacing: 4) {
                    // 计算百分比（放在外层，供下方使用）
                    let percentage = min(100, max(0, Double((spentThisMonth / monthlyBudget) * 100)))
                    HStack {
                        Text("Spent ¥\(spentThisMonth, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("\(percentage, specifier: "%.2f")%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(percentage > 80 ? .red : .secondary)
                    }
                    
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景条
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            // 填充条（现在可以用 percentage 了）
                            Capsule()
                                .fill(percentage > 80 ? Color.red : Color.blue)
                                .frame(
                                    width: geometry.size.width * CGFloat(min(1.0, spentThisMonth / monthlyBudget)),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.background)
                    .shadow(radius: 3)
            )
        }
        .buttonStyle(PlainButtonStyle()) // 去除按钮默认样式，保持视觉一致
    }
}

#Preview {
    BudgetCardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
