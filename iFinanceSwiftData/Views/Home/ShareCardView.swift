//
//  ShareCardView.swift
//  iFinance
//
//  分享专用卡片：今日统计 + 底部一行小字名言（已移除图片区域）
//

import SwiftUI

/// 分享专用卡片视图（包含当日记账统计）
struct ShareCardView: View {
    let sentence: DailySentence
    let periods: [PeriodSummary]   // 本月 / 上月 / 本年摘要
    let dailyBalance: Decimal   // 当日结余
    let incomeTotal: Decimal    // 当日收入
    let expenseTotal: Decimal   // 当日支出
    let billCount: Int          // 当日笔数
    let dateText: String        // 日期文字

    private var formattedBalance: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 2
        return f.string(from: NSDecimalNumber(decimal: dailyBalance)) ?? "¥0.00"
    }

    private var balanceColor: Color {
        dailyBalance >= 0
            ? Color(red: 0.18, green: 0.78, blue: 0.44)
            : Color(red: 1.0, green: 0.27, blue: 0.23)
    }

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            // ── 日期标题 ──
            Text(dateText)
                .font(AppTypography.tiny.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)

            // ── 结余金额 ──
            VStack(spacing: AppSpacing.xs) {
                Text(formattedBalance)
                    .appAmountStyle(size: 42, weight: .heavy)
                    .foregroundStyle(balanceColor)

                Text(dailyBalance >= 0 ? L10n.string("home.share_surplus") : L10n.string("home.share_deficit"))
                    .font(AppTypography.secondary.weight(.medium))
                    .foregroundStyle(dailyBalance >= 0 ? .green : .red)
            }

            Divider()

            // ── 三栏统计 ──
            HStack(spacing: AppSpacing.xl) {
                statColumn(title: "home.share_income", value: incomeTotal, color: .green)
                Divider().frame(height: AppSpacing.section)
                statColumn(title: "home.share_expense", value: expenseTotal, color: .red)
                Divider().frame(height: AppSpacing.section)
                statColumn(title: "home.share_count", value: "\(billCount)", color: .blue)
            }
            .padding(.horizontal, AppSpacing.md)

            Divider().opacity(0.5)

            // ── 周期摘要（本月 / 上月 / 本年） ──
            VStack(spacing: AppSpacing.sm) {
                ForEach(periods) { item in
                    HStack(spacing: AppSpacing.md) {
                        Text(L10n.string(item.period.titleKey))
                            .font(AppTypography.tiny)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: AppSpacing.sm)

                        Text(compactAmount(item.income))
                            .font(AppTypography.tiny.weight(.medium))
                            .foregroundStyle(.green)

                        Text(compactAmount(item.expense))
                            .font(AppTypography.tiny.weight(.medium))
                            .foregroundStyle(.red)

                        Text(compactAmount(item.balance))
                            .font(AppTypography.amount(13, weight: .semibold))
                            .foregroundStyle(item.balance >= 0 ? Color(red: 0.18, green: 0.78, blue: 0.44)
                                                                : Color(red: 1.0, green: 0.27, blue: 0.23))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xs)

            Divider().opacity(0.5)

            // ── 底部：一行小字名言 ──
            VStack(spacing: AppSpacing.xs) {
                Text(sentence.content)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text("—— \(sentence.note)")
                    .font(AppTypography.tiny)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, AppSpacing.sm)

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func statColumn(title: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(AppTypography.tiny)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 紧凑金额（用于周期摘要行）
    private func compactAmount(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 0
        return f.string(from: NSDecimalNumber(decimal: value)) ?? "¥0"
    }

    private func statColumn(title: LocalizedStringKey, value: Decimal, color: Color) -> some View {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 1
        let v = f.string(from: NSDecimalNumber(decimal: value)) ?? "¥0"
        return statColumn(title: title, value: v, color: color)
    }
}

#Preview {
    ShareCardView(
        sentence: DailySentence(content: "投资的关键在于，在别人贪婪时恐惧，在别人恐惧时贪婪。", note: "沃伦·巴菲特"),
        periods: [
            PeriodSummary(period: .thisMonth, income: 12000, expense: 4300, count: 26),
            PeriodSummary(period: .lastMonth, income: 11000, expense: 5200, count: 31),
            PeriodSummary(period: .thisYear, income: 132000, expense: 58000, count: 312)
        ],
        dailyBalance: 1800,
        incomeTotal: 5000,
        expenseTotal: 3200,
        billCount: 12,
        dateText: "4月23日 星期三"
    )
    .frame(width: 375, height: 560)
}
