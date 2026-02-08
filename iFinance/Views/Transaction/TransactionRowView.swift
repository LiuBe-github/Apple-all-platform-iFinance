//
//  TransactionRowView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/3.
//

import SwiftUI

// 单个账单行视图
struct TransactionRowView: View {
    @ObservedObject var bill: Bill
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            if let categoryRawValue = bill.category {
                if let expenditureCategory = ExpenditureCategory(rawValue: categoryRawValue) {
                    Image(systemName: expenditureCategory.icon)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle()
                            .fill(getCategoryColor(category: bill.type ?? "nil")))
                } else if let incomeCategory = IncomeCategory(rawValue: categoryRawValue) {
                    Image(systemName: incomeCategory.icon)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle()
                            .fill(getCategoryColor(category: bill.type ?? "nil")))
                } else if bill.type == "transfer" {
                    Image(systemName: "questionmark.circle")
                        .font(.body)
                        .foregroundColor(.gray)
                        .frame(width: 40, height: 40)
                        .background(Circle()
                            .fill(getCategoryColor(category: bill.type ?? "nil")))
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.body)
                        .foregroundColor(.gray)
                        .frame(width: 40, height: 40)
                }
            } else {
                Image(systemName: "circle")
                    .font(.body)
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }
            
            // 名称和时间
            VStack(alignment: .leading, spacing: 4) {
                Text(bill.category ?? "未分类")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let time = bill.date {
                    Text(formatTime(time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 金额
            if let amount = bill.amount?.doubleValue {
                let displayAmount = (bill.type == "expenditure") ? -amount : amount
                Text(displayAmount < 0 ? "-¥\( (abs(displayAmount)).formatted(.number.precision(.fractionLength(2))))" : "+¥\( displayAmount.formatted(.number.precision(.fractionLength(2))))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(displayAmount < 0 ? .red : .green)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle()) // 确保整个区域可点击
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 根据类别返回对应的颜色
    private func getCategoryColor(category: String) -> Color {
        switch category {
        case "expenditure":
            return Color.red
        case "income":
            return Color.green
        case "transfer":
            return Color.yellow
        default:
            return Color.gray // 默认颜色或处理未知类别
        }
    }
}
