//
//  TransactionRowView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/3.
//

import SwiftUI

struct TransactionRowView: View {
    let bill: Bill
    @Environment(\.colorScheme) private var colorScheme

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = Locale(identifier: "zh_CN")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()
    
    // MARK: - 解析分类（内置 / 自定义 / 「父/子」二级路径统一走 CategoryResolver）
    private enum BillCategory {
        case expenditure
        case income
        case transfer
        case unknown
    }

    private var billKind: CategoryKind? {
        CategoryKind(billType: bill.type ?? "")
    }

    private var resolvedCategory: BillCategory {
        if bill.type == "transfer" { return .transfer }
        guard let raw = bill.category, let kind = billKind,
              CategoryResolver.isValid(raw, kind: kind) else { return .unknown }
        return kind == .expenditure ? .expenditure : .income
    }

    private var icon: String {
        switch resolvedCategory {
        case .expenditure, .income:
            guard let raw = bill.category, let kind = billKind else { return "tag" }
            return CategoryResolver.icon(for: raw, kind: kind)
        case .transfer: return "arrow.left.arrow.right"
        case .unknown: return "questionmark"
        }
    }

    private var categoryText: Text {
        switch resolvedCategory {
        case .expenditure, .income:
            guard let raw = bill.category, let kind = billKind else {
                return Text(bill.category ?? L10n.string("bill.uncategorized"))
            }
            return Text(CategoryResolver.displayName(for: raw, kind: kind))
        case .transfer: return Text("bill.type_transfer")
        case .unknown: return Text(bill.category ?? L10n.string("bill.uncategorized"))
        }
    }
    
    private var iconColor: Color {
        switch resolvedCategory {
        case .expenditure:
            return ChartSeriesStyle.expense(for: colorScheme)  // 红＝支出
        case .income:
            return ChartSeriesStyle.income(for: colorScheme)   // 绿＝收入
        case .transfer:
            return Color(red: 0.10, green: 0.75, blue: 0.85)  // 青
        case .unknown:
            return Color(red: 0.55, green: 0.55, blue: 0.60)  // 灰
        }
    }
    
    // MARK: - 金额
    private var amount: Double {
        let v = bill.amountDouble
        return bill.type == "expenditure" ? -v : v
    }
    
    private var amountText: String {
        let abs = Swift.abs(amount)
        let str = Self.amountFormatter.string(from: NSNumber(value: abs)) ?? "¥\(abs)"
        return amount >= 0 ? "+\(str)" : "-\(str)"
    }
    
    private var amountColor: Color {
        if bill.type == "transfer" {
            return .secondary
        }
        return amount >= 0
        ? ChartSeriesStyle.income(for: colorScheme)
        : Color(red: 1.0,  green: 0.27, blue: 0.23)
    }
    
    // MARK: - 时间
    private var timeText: String {
        guard let date = bill.date else { return "" }
        return Self.timeFormatter.string(from: date)
    }

    /// 备注（去掉首尾空白；空串视为没有备注）
    private var noteText: String {
        (bill.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            
            // 图标圆圈（渐变底）
            Image(systemName: icon)
                .font(AppTypography.secondary.weight(.medium))
                .foregroundStyle(iconColor)
                .appIconTile(iconColor)
            
            // 备注为主、分类 · 时间为次；没有备注时回退为「分类 + 时间」
            VStack(alignment: .leading, spacing: 3) {
                if noteText.isEmpty {
                    categoryText
                        .font(AppTypography.secondary.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !timeText.isEmpty {
                        Text(timeText)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(noteText)
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: AppSpacing.xs) {
                        categoryText
                        if !timeText.isEmpty {
                            Text("·")
                            Text(timeText)
                        }
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 金额
            Text(amountText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(amountColor)
                .appNumericTransition(value: amount)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .contentShape(Rectangle())
    }
}
