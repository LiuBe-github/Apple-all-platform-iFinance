//
//  EditBudgetView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/1.
//

// MARK: This file has been deprecated.
import SwiftUI
internal import CoreData

struct EditBudgetView: View {
    @Binding var budget: Double
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Edit Monthly Budget")
                    .font(.title2)
                
                TextField("Enter budget", value: $budget, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // 保存预算数值的逻辑
                        saveBudget()
                        // 退出当前页面
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveBudget() { // MARK: 这个函数压根没用，考虑删掉
        // 这里可以添加保存预算的逻辑

        // 如果你使用CoreData，可以在这里添加CoreData保存逻辑
        print("预算已保存: ¥\(budget)。")
    }
}

#Preview {
    NavigationStack {
        EditBudgetView(budget: .constant(3000.0))
            .navigationBarTitleDisplayMode(.inline)
    }
}
