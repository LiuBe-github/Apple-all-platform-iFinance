//
//  TodayBalanceCard.swift
//  iFinance
//
//  今日结余卡片（首页顶部，紧凑版）
//

import SwiftUI

/// 今日结余卡片（首页顶部，紧凑版）
struct TodayBalanceCard: View {
    let income: Decimal
    let expense: Decimal
    let balance: Decimal
    let billCount: Int

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = .autoupdatingCurrent
        return f
    }()

    private func formatted(_ value: Decimal) -> String {
        Self.currencyFormatter.maximumFractionDigits = value == 0 || abs(value) >= 1000 ? 0 : 2
        Self.currencyFormatter.minimumFractionDigits = 0
        return Self.currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "¥0"
    }

    /// 日期文字
    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            // ── 左侧：金额 ──
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatted(balance))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(balance >= 0 ? Color(red: 0.18, green: 0.78, blue: 0.44) : Color(red: 1.0, green: 0.27, blue: 0.23))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(balance >= 0 ? String(localized: "home.surplus") : String(localized: "home.deficit"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(balance >= 0 ? .green.opacity(0.7) : .red.opacity(0.7))
                }
            }

            Spacer()

            // ── 右侧：三栏统计 ──
            HStack(spacing: 14) {
                miniStat(icon: "arrow.down.circle.fill", color: .green,
                         value: formatted(income), label: String(localized: "home.income_label"))
                miniStat(icon: "arrow.up.circle.fill", color: .red,
                         value: formatted(expense), label: String(localized: "home.expense_label"))
                miniStat(icon: "list.bullet.clipboard.fill", color: .blue,
                         value: "\(billCount)", label: String(localized: "home.count_label"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .appGlassCard(cornerRadius: 20)
    }

    private func miniStat(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
        }
    }
}

#Preview {
    TodayBalanceCard(
        income: 5000,
        expense: 3200,
        balance: 1800,
        billCount: 12
    )
    .padding()
}
