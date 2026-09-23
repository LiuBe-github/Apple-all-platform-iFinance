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

    @State private var appeared = false

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

    private var balanceColor: Color {
        balance >= 0 ? Color(red: 0.18, green: 0.78, blue: 0.44) : Color(red: 1.0, green: 0.27, blue: 0.23)
    }

    var body: some View {
        HStack(spacing: 12) {
            // ── 左侧：金额 ──
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(dateLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(formatted(balance))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(balanceColor)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .appNumericTransition(value: NSDecimalNumber(decimal: balance).doubleValue)

                    Text(balance >= 0 ? String(localized: "home.surplus") : String(localized: "home.deficit"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(balanceColor.opacity(0.7))
                        .transition(.opacity)
                }
            }

            Spacer()

            // ── 右侧：三栏统计 ──
            HStack(spacing: 12) {
                miniStat(icon: "arrow.down.circle.fill", tint: .green,
                         value: formatted(income), label: String(localized: "home.income_label"))
                miniStat(icon: "arrow.up.circle.fill", tint: .red,
                         value: formatted(expense), label: String(localized: "home.expense_label"))
                miniStat(icon: "list.bullet.clipboard.fill", tint: .blue,
                         value: "\(billCount)", label: String(localized: "home.count_label"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .appGlassCard(cornerRadius: 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.05)) {
                appeared = true
            }
        }
    }

    private func miniStat(icon: String, tint: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.20), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(tint.opacity(0.25), lineWidth: 0.8)
                    )
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 26, height: 26)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
        }
        .frame(minWidth: 40)
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
