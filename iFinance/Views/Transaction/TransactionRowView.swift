//
//  TransactionRowView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/3.
//

import SwiftUI

struct TransactionRowView: View {
    @ObservedObject var bill: Bill
    
    // MARK: - 解析分类
    private enum BillCategory {
        case expenditure(ExpenditureCategory)
        case income(IncomeCategory)
        case transfer
        case unknown
    }
    
    private var resolvedCategory: BillCategory {
        guard let raw = bill.category else { return .unknown }
        if let c = ExpenditureCategory(rawValue: raw) { return .expenditure(c) }
        if let c = IncomeCategory(rawValue: raw)      { return .income(c) }
        if bill.type == "transfer"                    { return .transfer }
        return .unknown
    }
    
    private var icon: String {
        switch resolvedCategory {
        case .expenditure(let c): return c.icon
        case .income(let c):      return c.icon
        case .transfer:           return "arrow.left.arrow.right"
        case .unknown:            return "questionmark"
        }
    }
    
    private var categoryName: String {
        switch resolvedCategory {
        case .expenditure(let c): return c.rawValue
        case .income(let c):      return c.rawValue
        case .transfer:           return "转账"
        case .unknown:            return bill.category ?? "未分类"
        }
    }
    
    private var iconColor: Color {
        switch resolvedCategory {
        case .expenditure:
            return Color(red: 1.0,  green: 0.27, blue: 0.23)  // 红
        case .income:
            return Color(red: 0.18, green: 0.78, blue: 0.44)  // 绿
        case .transfer:
            return Color(red: 0.10, green: 0.75, blue: 0.85)  // 青
        case .unknown:
            return Color(red: 0.55, green: 0.55, blue: 0.60)  // 灰
        }
    }
    
    // MARK: - 金额
    private var amount: Double {
        let v = bill.amount?.doubleValue ?? 0
        return bill.type == "expenditure" ? -v : v
    }
    
    private var amountText: String {
        let abs = Swift.abs(amount)
        let f = NumberFormatter()
        f.numberStyle           = .currency
        f.currencySymbol        = "¥"
        f.locale                = Locale(identifier: "zh_CN")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        let str = f.string(from: NSNumber(value: abs)) ?? "¥\(abs)"
        return amount >= 0 ? "+\(str)" : "-\(str)"
    }
    
    private var amountColor: Color {
        if bill.type == "transfer" {
            return .secondary
        }
        return amount >= 0
        ? Color(red: 0.18, green: 0.78, blue: 0.44)
        : Color(red: 1.0,  green: 0.27, blue: 0.23)
    }
    
    // MARK: - 时间
    private var timeText: String {
        guard let date = bill.date else { return "" }
        let f = DateFormatter()
        f.locale     = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 12) {
            
            // 图标圆圈
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            
            // 分类名 + 时间
            VStack(alignment: .leading, spacing: 3) {
                Text(categoryName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if !timeText.isEmpty {
                    Text(timeText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // 金额
            Text(amountText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(amountColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
