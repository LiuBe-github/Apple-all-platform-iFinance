//
//  ChartAxisSupport.swift
//  iFinance
//
//  图表坐标轴支撑（纯函数，可单测）：
//  - R2：柱状图 y 轴下界固定 0（双向柱状图跨 0 属合理特例）
//  - R3：上界随数据动态适配
//  - R4：横向网格线 3–5 条、步长为整齐数字（1 / 2 / 2.5 / 5 × 10ⁿ）
//  - R6：轴标签紧凑简短，单位「¥」不进轴标签（由标题 / 副标题承担）
//
//  参考：WWDC22 110340《Design an effective chart》——柱状图从 0 起、网格线 3–5 条、刻度取整。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation

/// 一根轴需要的域与刻度
struct ChartAxisModel: Equatable {
    let domain: ClosedRange<Double>
    let ticks: [Double]
}

enum ChartAxisSupport {

    /// 目标网格线条数（含下界与上界）
    static let targetTickCount = 4

    // MARK: - 刻度步长

    /// 取「不小于 raw 的最小整齐步长」：1 / 2 / 2.5 / 5 × 10ⁿ
    static func niceStep(atLeast raw: Double) -> Double {
        guard raw > 0, raw.isFinite else { return 1 }
        let exponent = (log10(raw)).rounded(.down)
        let magnitude = pow(10, exponent)
        let normalized = raw / magnitude          // 落在 1..10
        let candidates: [Double] = [1, 2, 2.5, 5, 10]
        let picked = candidates.first { $0 >= normalized - 1e-9 } ?? 10
        return picked * magnitude
    }

    // MARK: - 单系列柱状图（下界 0）

    /// R2 + R3 + R4：`0...整齐上界` 与其中的刻度
    static func barAxis(maxValue: Double) -> ChartAxisModel {
        let safeMax = max(maxValue, 0)
        guard safeMax > 0 else {
            // 全 0 数据：给一个可读的最小刻度
            return ChartAxisModel(domain: 0...1, ticks: [0, 0.5, 1])
        }
        let step = niceStep(atLeast: safeMax / Double(targetTickCount))
        let upper = (safeMax / step).rounded(.up) * step
        return ChartAxisModel(domain: 0...upper, ticks: ticks(from: 0, through: upper, step: step))
    }

    // MARK: - 双向柱状图（跨 0，两侧共用步长）

    /// R2 特例：收入在 0 上、支出在 0 下；两侧用同一步长，且 0 始终是刻度
    static func bidirectionalAxis(minValue: Double, maxValue: Double) -> ChartAxisModel {
        let upperSide = max(maxValue, 0)
        let lowerSide = max(-minValue, 0)
        let extent = max(upperSide, lowerSide)
        guard extent > 0 else {
            return ChartAxisModel(domain: -1...1, ticks: [-1, 0, 1])
        }
        let step = niceStep(atLeast: extent / Double(targetTickCount))
        let upper = (upperSide / step).rounded(.up) * step
        let lower = -((lowerSide / step).rounded(.up) * step)
        let finalUpper = max(upper, step)
        let finalLower = min(lower, -step)
        return ChartAxisModel(
            domain: finalLower...finalUpper,
            ticks: ticks(from: finalLower, through: finalUpper, step: step)
        )
    }

    /// 在 [from, through] 内按 step 生成刻度（首尾都包含，浮点误差已吸附到 step 的整数倍）
    static func ticks(from lower: Double, through upper: Double, step: Double) -> [Double] {
        guard step > 0, upper >= lower else { return [lower, upper] }
        var values: [Double] = []
        var value = lower
        // 最多 12 条，避免极端数据下无限循环
        while value <= upper + step * 1e-6, values.count < 12 {
            values.append((value / step).rounded() * step)
            value += step
        }
        if values.last.map({ abs($0 - upper) > step * 1e-6 }) == true {
            values.append((upper / step).rounded() * step)
        }
        return values
    }

    // MARK: - 轴标签（R6）

    /// 中文 / 日文用「万」，英文用「k」
    static func usesTenThousandUnit(for locale: Locale) -> Bool {
        let code = locale.language.languageCode?.identifier ?? locale.identifier
        return code.hasPrefix("zh") || code == "ja"
    }

    /// 紧凑轴标签：≥10000 时用「万 / k」，其余取整（单位由标题 / 副标题承担，轴上一律不带「¥」）
    static func compactAmount(_ value: Double, usesTenThousandUnit: Bool) -> String {
        let magnitude = abs(value)
        if magnitude >= 10_000 {
            let divisor = usesTenThousandUnit ? 10_000.0 : 1_000.0
            let scaled = value / divisor
            let digits = abs(scaled) >= 10 ? 0 : 1
            let unit = usesTenThousandUnit ? "万" : "k"
            return String(format: "%.\(digits)f%@", scaled, unit)
        }
        // 小于 1 万的刻度：最多 2 位小数并去掉尾随零。
        // 目的：0 / 0.25 / 0.5 / 0.75 这类小额刻度若直接取整会出现重复标签（"0","0","1"）。
        var text = String(format: "%.2f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }
}
