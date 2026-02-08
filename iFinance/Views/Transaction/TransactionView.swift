//
//  Transaction.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
internal import CoreData

struct TransactionView: View {
    @State private var isHeaderVisible = true
    
    // 添加一个 fetch request 来检查是否有账单
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        animation: .default
    ) private var bills: FetchedResults<Bill>
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                // 预算卡片
                BudgetCardView()
                    .padding(.horizontal)
                    .padding(.bottom)
                
                // 根据账单数量决定显示什么
                if !bills.isEmpty {
                    // 有账单时显示 BillsCardView
                    BillsCardView()
                        .padding(.horizontal)
                        .padding(.bottom)
                } else {
                    // 没有账单时显示提示文字
                    VStack {
                        Spacer()
                        Text("当前还没有账单哦，记一笔吧！😄")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxHeight: 400) // 设置一个合理的高度
                }
            }
            .navigationTitle("账本")
            .scrollIndicators(.automatic)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HeaderView(isTransactionView: true)
                }
            }
            .navigationBarBackButtonHidden(true)
        } 
    }
}

#Preview {
    TransactionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
