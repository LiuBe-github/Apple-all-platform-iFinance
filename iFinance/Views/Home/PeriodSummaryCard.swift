//
//  PeriodSummaryCard.swift
//  iFinance
//
//  周期概况卡：本月 / 上月 / 本年 三行明细（区间名 + 笔数 + 收支 + 结余）
//

import SwiftUI

struct PeriodSummaryCard: View {
    let periods: [PeriodSummary]

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = .autoupdatingCurrent
        return f
    }()

    private static func amount(_ value: Decimal) -> String {
        currencyFormatter.maximumFractionDigits = abs(value) >= 1000 ? 0 : 2
        currencyFormatter.minimumFractionDigits = 0
        return currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "¥0"
    }

    private static func balanceColor(_ value: Decimal) -> Color {
        value >= 0 ? Color(red: 0.18, green: 0.78, blue: 0.44) : Color(red: 1.0, green: 0.27, blue: 0.23)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(String(localized: "home.period.title"))
                .font(AppTypography.tiny.weight(.semibold))
                .foregroundStyle(.quaternary)

            VStack(spacing: 0) {
                ForEach(Array(periods.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().opacity(0.5)
                    }
                    row(for: item)
                }
            }
        }
        .padding(.horizontal, AppLayout.cardPaddingCozy)
        .padding(.vertical, AppLayout.cardPadding)
        .appGlassCard(cornerRadius: AppRadius.sheet)
    }

    private func row(for item: PeriodSummary) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            // ── 左：区间名 + 笔数 ──
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(L10n.string(item.period.titleKey))
                    .font(AppTypography.secondary.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(String(format: L10n.string("home.period.count_value"), item.count))
                    .font(AppTypography.tiny)
                    .foregroundStyle(.tertiary)
            }
            .frame(minWidth: 60, alignment: .leading)

            // ── 中：收入 / 支出 ──
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                amountLine(label: String(localized: "home.income_label"),
                           value: Self.amount(item.income), color: .green)
                amountLine(label: String(localized: "home.expense_label"),
                           value: Self.amount(item.expense), color: .red)
            }

            Spacer(minLength: AppSpacing.sm)

            // ── 右：结余 ──
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                Text(Self.amount(item.balance))
                    .font(AppTypography.amount(17, weight: .semibold))
                    .foregroundStyle(Self.balanceColor(item.balance))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(item.balance >= 0
                     ? String(localized: "home.surplus")
                     : String(localized: "home.deficit"))
                    .font(AppTypography.tiny)
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, AppSpacing.md)
        .accessibilityElement(children: .combine)
    }

    private func amountLine(label: String, value: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.tiny)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(AppTypography.amount(13, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

#Preview {
    PeriodSummaryCard(periods: [
        PeriodSummary(period: .thisMonth, income: 12000, expense: 4300, count: 26),
        PeriodSummary(period: .lastMonth, income: 11000, expense: 5200, count: 31),
        PeriodSummary(period: .thisYear, income: 132000, expense: 58000, count: 312)
    ])
    .padding()
}
