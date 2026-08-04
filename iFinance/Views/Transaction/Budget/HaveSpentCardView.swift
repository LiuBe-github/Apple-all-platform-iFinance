//
//  HaveSpentCardView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI

//
//  BudgetCard.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
internal import CoreData

struct HaveSpentCardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        predicate: PersistenceController.billUserPredicate,
        animation: .default
    ) private var bills: FetchedResults<Bill>
    
    // 自动获取当前月份的所有支出账单
    @FetchRequest private var currentMonthBills: FetchedResults<Bill>
    
    init() {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            // fallback 初始化（也必须有 sortDescriptors！）
            let request: NSFetchRequest<Bill> = Bill.fetchRequest()
            request.predicate = PersistenceController.billUserPredicate
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
            _currentMonthBills = FetchRequest(fetchRequest: request)
            return
        }
        
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        /* 等价于SQL语句：
         select *
         from Bill
         where type = "expenditure"
         and date >= startOfMonth as NSDate
         and date < ndOfMonth as NSDate
         and createBy == PersistenceController.currentUserIdentifier;
         */
        request.predicate = NSPredicate(format: """
            type == %@ AND 
            date >= %@ AND 
            date < %@ AND 
            amount != nil AND
            createdBy == %@
            """,
                                        "expenditure",
                                        startOfMonth as NSDate,
                                        endOfMonth as NSDate,
                                        PersistenceController.currentUserIdentifier
        )
        
        // 关键修复：添加排序描述符
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
        VStack(alignment: .leading, spacing: 9) {
            // 标题
            Text("budget.this_month_expense")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("¥\(spentThisMonth, specifier: "%.2f")")
                .font(.largeTitle)
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
                            Color.yellow,
                            Color.red
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(radius: 3)
    }
}


#Preview {
    HaveSpentCardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
