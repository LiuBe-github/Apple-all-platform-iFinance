//
//  ChartSummary.swift
//  iFinance
//
//  R7：图表标题 / 副标题要能独立读懂并含主结论。
//  这里只做「把已有数值组合成一句话」，不新增取数口径：
//  - 单系列：`<区间> · 合计 ¥x · 日均 ¥y`
//  - 总收支：`<区间> · 净额 +¥z`
//
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation

enum ChartSummary {

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.locale = .autoupdatingCurrent
        return f
    }()

    /// 金额文本（不带符号）
    static func amount(_ value: Double) -> String {
        amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    /// 带正负号的金额文本（正数补「+」）
    static func signedAmount(_ value: Double) -> String {
        let text = amount(abs(value))
        return (value < 0 ? "-" : "+") + text
    }

    /// 区间文本：`6月1日 – 6月30日` / `2025年7月 – 2026年6月`
    static func rangeText(from: Date, to: Date, monthly: Bool) -> String {
        if monthly {
            let start = from.formatted(.dateTime.year().month())
            let end = to.formatted(.dateTime.year().month())
            return "\(start) – \(end)"
        }
        let start = from.formatted(.dateTime.month().day())
        let end = to.formatted(.dateTime.month().day())
        return "\(start) – \(end)"
    }

    /// 单系列副标题（R7）
    static func periodSubtitle(rangeText: String, total: Double, average: Double) -> String {
        let totalLabel = L10n.string("chart.summary.total")
        let averageLabel = L10n.string("chart.summary.average")
        return "\(rangeText) · \(totalLabel) ¥\(amount(total)) · \(averageLabel) ¥\(amount(average))"
    }

    /// 总收支副标题（R7）
    static func netSubtitle(rangeText: String, net: Double) -> String {
        let netLabel = L10n.string("tendency.net.net")
        return "\(rangeText) · \(netLabel) \(signedAmount(net))"
    }
}
