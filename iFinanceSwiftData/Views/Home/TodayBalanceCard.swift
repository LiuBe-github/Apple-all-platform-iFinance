//
//  TodayBalanceCard.swift
//  iFinance
//
//  今日概况卡片（首页主视觉：日期 + 大号结余 + 收入/支出/笔数三栏）
//

import SwiftUI

/// 今日概况卡片（首页顶部主视觉）
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
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // ── 顶部：日期 + 卡片标题 ──
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)

                Text(dateLabel)
                    .font(AppTypography.tiny.weight(.medium))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: AppSpacing.sm)

                Text(L10n.string("home.today_balance"))
                    .font(AppTypography.tiny.weight(.medium))
                    .foregroundStyle(.quaternary)
            }

            // ── 主视觉：今日结余（收入 − 支出，纯数字，不做文字描述） ──
            Text(formatted(balance))
                .appAmountStyle(size: 40, weight: .heavy)
                .foregroundStyle(balanceColor)
                .appNumericTransition(value: NSDecimalNumber(decimal: balance).doubleValue)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().opacity(0.5)

            // ── 底部：收入 / 支出 / 笔数 ──
            HStack(spacing: AppSpacing.md) {
                miniStat(icon: "arrow.down.circle.fill", tint: .green,
                         value: formatted(income), label: L10n.string("home.income_label"))
                miniStat(icon: "arrow.up.circle.fill", tint: .red,
                         value: formatted(expense), label: L10n.string("home.expense_label"))
                miniStat(icon: "list.bullet.clipboard.fill", tint: .blue,
                         value: "\(billCount)", label: L10n.string("home.count_label"))
            }
        }
        .padding(.horizontal, AppLayout.cardPaddingCozy)
        .padding(.vertical, AppLayout.cardPadding)
        .appGlassCard(cornerRadius: AppRadius.sheet)
        .appEntrance(index: 0, visible: appeared)
        .onAppear { appeared = true }
    }

    private func miniStat(icon: String, tint: Color, value: String, label: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.20), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                            .strokeBorder(tint.opacity(0.25), lineWidth: 0.8)
                    )
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: AppLayout.iconTile, height: AppLayout.iconTile)

            Text(value)
                .font(AppTypography.amount(15, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(AppTypography.tiny)
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: AppLayout.listRowMinHeight)
        .accessibilityElement(children: .combine)
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
