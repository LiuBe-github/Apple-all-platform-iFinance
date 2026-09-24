//
//  CategoryBreakdown.swift
//  iFinance
//
//  分类占比聚合（纯函数，便于单测）：用于趋势页的支出 / 收入分类饼图。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation

/// 单个分类的占比数据
struct CategorySlice: Identifiable {
    /// 分类 rawValue（如「餐饮」）；无法解析时按原字符串展示
    let rawValue: String
    let amount: Double
    let count: Int

    var id: String { rawValue }
}

enum CategoryBreakdown {
    /// 最近 `days` 天（含今天）内指定账单类型的分类汇总，按金额降序（同额按 rawValue 升序）
    /// - Parameters:
    ///   - type: `"expenditure"` / `"income"`（转账不计入）
    static func slices(
        bills: some Collection<Bill>,
        type: String,
        days: Int,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [CategorySlice] {
        guard days > 0 else { return [] }

        let startOfToday = calendar.startOfDay(for: now)
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) ?? startOfToday
        let window = windowStart..<windowEnd

        var amounts: [String: Double] = [:]
        var counts: [String: Int] = [:]

        for bill in bills {
            guard bill.type == type, let date = bill.date, window.contains(date) else { continue }
            guard let raw = bill.category?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            amounts[raw, default: 0] += bill.amount?.doubleValue ?? 0
            counts[raw, default: 0] += 1
        }

        return amounts
            .map { CategorySlice(rawValue: $0.key, amount: $0.value, count: counts[$0.key] ?? 0) }
            .sorted { lhs, rhs in
                lhs.amount == rhs.amount ? lhs.rawValue < rhs.rawValue : lhs.amount > rhs.amount
            }
    }

    /// 各分类金额合计
    static func total(of slices: [CategorySlice]) -> Double {
        slices.reduce(0) { $0 + $1.amount }
    }
}

