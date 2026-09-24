//
//  PeriodSummary.swift
//  iFinance
//
//  概况页的区间统计：本月 / 上月 / 本年的取数窗口与聚合纯函数。
//

import Foundation

// MARK: - 统计区间

enum SummaryPeriod: String, CaseIterable, Identifiable {
    case thisMonth
    case lastMonth
    case thisYear

    var id: String { rawValue }

    /// 本地化标题 key
    var titleKey: String {
        switch self {
        case .thisMonth: return "home.period.this_month"
        case .lastMonth: return "home.period.last_month"
        case .thisYear:  return "home.period.this_year"
        }
    }
}

// MARK: - 区间汇总

/// 单个区间的收支汇总（笔数包含收入与支出）
struct PeriodSummary: Identifiable {
    let period: SummaryPeriod
    let income: Decimal
    let expense: Decimal
    let count: Int

    var id: String { period.rawValue }

    /// 结余 = 收入 − 支出
    var balance: Decimal { income - expense }
}

// MARK: - 时间窗口（自然月 / 自然年）

struct PeriodRanges {
    /// 今天
    let today: Range<Date>
    /// 当前自然月至今
    let thisMonth: Range<Date>
    /// 上一个自然月（完整）
    let lastMonth: Range<Date>
    /// 今年 1 月 1 日至今（YTD）
    let thisYear: Range<Date>

    /// 覆盖「本月 + 上月 + 本年」的取数窗口（1 月时包含去年 12 月）
    var fetchWindow: Range<Date> {
        let start = min(thisYear.lowerBound, lastMonth.lowerBound)
        return start..<today.upperBound
    }

    func range(for period: SummaryPeriod) -> Range<Date> {
        switch period {
        case .thisMonth: return thisMonth
        case .lastMonth: return lastMonth
        case .thisYear:  return thisYear
        }
    }

    static func make(calendar: Calendar = .current, now: Date = Date()) -> PeriodRanges {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth) ?? startOfMonth
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? startOfToday

        return PeriodRanges(
            today: startOfToday..<startOfTomorrow,
            thisMonth: startOfMonth..<startOfTomorrow,
            lastMonth: startOfLastMonth..<startOfMonth,
            thisYear: startOfYear..<startOfTomorrow
        )
    }
}

// MARK: - 聚合

extension PeriodSummary {
    /// 按区间聚合账单（纯函数，便于单元测试）
    /// - 说明：`transfer` 计入笔数，但不计入收入 / 支出，与今日卡口径一致。
    static func make(
        bills: some Collection<Bill>,
        ranges: PeriodRanges,
        periods: [SummaryPeriod] = SummaryPeriod.allCases
    ) -> [PeriodSummary] {
        periods.map { period in
            let range = ranges.range(for: period)
            var income: Decimal = 0
            var expense: Decimal = 0
            var count = 0

            for bill in bills {
                guard let date = bill.date, range.contains(date) else { continue }
                count += 1
                let amount = bill.amount?.decimalValue ?? 0
                switch bill.type {
                case "income":      income += amount
                case "expenditure": expense += amount
                default:            break
                }
            }

            return PeriodSummary(period: period, income: income, expense: expense, count: count)
        }
    }
}

