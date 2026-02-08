//
//  BudgetView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI
internal import CoreData

struct BudgetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // 获取当前月份的所有支出账单（用于计算总支出）
    @FetchRequest private var currentMonthExpenditures: FetchedResults<Bill>
    
    // 初始化：获取本月所有 type == "expenditure" 的账单
    init() {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            // fallback
            let request: NSFetchRequest<Bill> = Bill.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
            _currentMonthExpenditures = FetchRequest(fetchRequest: request)
            return
        }
        
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = NSPredicate(format: """
            type == %@ AND 
            date >= %@ AND 
            date < %@ AND 
            amount != nil AND 
            category != NULL
            """,
                                        "expenditure",
                                        startOfMonth as NSDate,
                                        endOfMonth as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
        _currentMonthExpenditures = FetchRequest(fetchRequest: request)
    }
    
    // 计算本月总支出（仅支出类型）
    private var totalExpenditure: Double {
        currentMonthExpenditures.reduce(0) { sum, bill in
            sum + (bill.amount?.doubleValue ?? 0)
        }
    }
    
    // 按分类汇总支出金额
    private var expenditureByCategory: [(category: ExpenditureCategory, amount: Double)] {
        var dict: [ExpenditureCategory: Double] = [:]
        
        for bill in currentMonthExpenditures {
            guard let categoryStr = bill.category,
                  let category = ExpenditureCategory(rawValue: categoryStr),
                  let amount = bill.amount?.doubleValue else {
                continue
            }
            dict[category, default: 0] += amount
        }
        
        // 返回所有分类（即使金额为0），按金额降序排列
        return ExpenditureCategory.allCases.map { category in
            (category: category, amount: dict[category] ?? 0)
        }
        .sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 预算卡片作为列表的第一个 section
                Section {
                    BudgetCardSecondaryView() // 使用第二预算卡片
                } header: {
                    Text("预算概览")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .navigationLinkIndicatorVisibility(.hidden) // 禁用箭头
                // 消费卡片作为列表的第儿个 section
                Section {
                    HaveSpentCardView()
                } header: {
                    Text("本月已花")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .navigationLinkIndicatorVisibility(.hidden) // 禁用箭头
                
                // 分类支出详情
                ForEach(expenditureByCategory, id: \.category) { item in
                    CategoryRowView(
                        category: item.category,
                        amount: item.amount,
                        total: totalExpenditure
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("本月支出占比及预算管理")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}

// 单个分类行视图
struct CategoryRowView: View {
    let category: ExpenditureCategory
    let amount: Double
    let total: Double
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return (amount / total) * 100
    }
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.rawValue)
                    .font(.headline)
                
                // 进度条容器
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        // 前景（进度）
                        Capsule()
                            .fill(Color.blue)
                            .frame(
                                width: geometry.size.width * CGFloat(min(1.0, percentage / 100)),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(percentage, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 80)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    BudgetView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
