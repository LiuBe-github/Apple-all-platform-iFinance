//
//  ChartGuidelineTests.swift
//  iFinanceTests
//
//  趋势页图表对齐 Apple 图表规范（R1–R22）的纯逻辑回归：
//  - R2/R3/R4：柱状图下界 0、上界随数据、3–5 条整齐刻度
//  - R6：紧凑轴标签
//  - R7：副标题结论
//  - R14：形状 / 符号通道
//  - R16：配色对比度与明度均衡、热力等级亮度单调
//

import XCTest
@testable import iFinance

final class ChartGuidelineTests: XCTestCase {

    // MARK: - R2 / R3 / R4：坐标轴

    func testBarAxisAlwaysStartsAtZeroAndCoversData() {
        for maxValue in [1.0, 3, 7, 99, 1234, 12345] {
            let model = ChartAxisSupport.barAxis(maxValue: maxValue)
            XCTAssertEqual(model.domain.lowerBound, 0, "R2：柱状图 y 轴下界必须为 0（max=\(maxValue)）")
            XCTAssertGreaterThanOrEqual(model.domain.upperBound, maxValue, "R3：上界要覆盖数据（max=\(maxValue)）")
        }
    }

    func testBarAxisProducesThreeToFiveNiceTicks() {
        for maxValue in [1.0, 3, 7, 99, 1234, 12345] {
            let model = ChartAxisSupport.barAxis(maxValue: maxValue)
            XCTAssertGreaterThanOrEqual(model.ticks.count, 3, "R4：刻度不少于 3 条（max=\(maxValue)）")
            XCTAssertLessThanOrEqual(model.ticks.count, 5, "R4：刻度不多于 5 条（max=\(maxValue)）")
            XCTAssertEqual(model.ticks.first ?? -1, 0, accuracy: 1e-9, "R4：刻度应包含 0")
            assertEvenlySpacedNiceSteps(model.ticks, label: "max=\(maxValue)")
        }
    }

    func testZeroDataStillGivesReadableAxis() {
        let model = ChartAxisSupport.barAxis(maxValue: 0)
        XCTAssertEqual(model.domain.lowerBound, 0)
        XCTAssertGreaterThan(model.domain.upperBound, 0)
        XCTAssertGreaterThanOrEqual(model.ticks.count, 3)
    }

    func testBidirectionalAxisCrossesZeroWithSharedStep() {
        let model = ChartAxisSupport.bidirectionalAxis(minValue: -40, maxValue: 100)
        XCTAssertLessThan(model.domain.lowerBound, 0, "R2 特例：双向图跨 0")
        XCTAssertGreaterThan(model.domain.upperBound, 0)
        XCTAssertTrue(model.ticks.contains(0), "R4：0 必须是刻度")
        assertEvenlySpacedNiceSteps(model.ticks, label: "双向图")
    }

    func testBidirectionalAxisWhenOnlyIncomeExistsStopsAtZero() {
        let model = ChartAxisSupport.bidirectionalAxis(minValue: 0, maxValue: 500)
        XCTAssertEqual(model.domain.lowerBound, -ChartAxisSupport.niceStep(atLeast: 125), accuracy: 1e-9,
                       "只有一个方向有数据时，另一侧仍留一个整齐步长以保持零轴可见")
        XCTAssertGreaterThanOrEqual(model.domain.upperBound, 500)
    }

    // MARK: - R6：紧凑轴标签

    func testCompactAmountUsesTenThousandOrKilo() {
        XCTAssertEqual(ChartAxisSupport.compactAmount(3500, usesTenThousandUnit: true), "3500")
        XCTAssertEqual(ChartAxisSupport.compactAmount(12_300, usesTenThousandUnit: true), "1.2万")
        XCTAssertEqual(ChartAxisSupport.compactAmount(123_000, usesTenThousandUnit: true), "12万")
        XCTAssertEqual(ChartAxisSupport.compactAmount(12_300, usesTenThousandUnit: false), "12k")
        XCTAssertEqual(ChartAxisSupport.compactAmount(-15_000, usesTenThousandUnit: true), "-1.5万")
        // 小额刻度不能被取整成重复标签
        XCTAssertEqual(ChartAxisSupport.compactAmount(0.25, usesTenThousandUnit: true), "0.25")
        XCTAssertEqual(ChartAxisSupport.compactAmount(0.5, usesTenThousandUnit: true), "0.5")
        XCTAssertEqual(ChartAxisSupport.compactAmount(1, usesTenThousandUnit: true), "1")
        XCTAssertEqual(ChartAxisSupport.compactAmount(78.5, usesTenThousandUnit: true), "78.5")
    }

    func testTenThousandUnitFollowsLanguage() {
        XCTAssertTrue(ChartAxisSupport.usesTenThousandUnit(for: Locale(identifier: "zh-Hans")))
        XCTAssertTrue(ChartAxisSupport.usesTenThousandUnit(for: Locale(identifier: "ja")))
        XCTAssertFalse(ChartAxisSupport.usesTenThousandUnit(for: Locale(identifier: "en")))
    }

    // MARK: - R7：副标题结论

    func testPeriodSubtitleContainsRangeTotalAndAverage() {
        let text = ChartSummary.periodSubtitle(rangeText: "6月1日 – 6月30日", total: 2340, average: 78)
        XCTAssertTrue(text.contains("6月1日 – 6月30日"), "R7：副标题要含区间")
        XCTAssertTrue(text.contains(L10n.string("chart.summary.total")), "R7：副标题要含「合计」结论")
        XCTAssertTrue(text.contains(L10n.string("chart.summary.average")), "R7：副标题要含「日均」结论")
        XCTAssertTrue(text.contains("¥"))
    }

    func testNetSubtitleCarriesSignedNet() {
        XCTAssertTrue(ChartSummary.netSubtitle(rangeText: "6月", net: 520).contains("+520"))
        XCTAssertTrue(ChartSummary.netSubtitle(rangeText: "6月", net: -120).contains("-120"))
    }

    func testSignedAmountKeepsSign() {
        XCTAssertTrue(ChartSummary.signedAmount(520).hasPrefix("+"))
        XCTAssertTrue(ChartSummary.signedAmount(-120).hasPrefix("-"))
    }

    // MARK: - R14：形状 / 符号通道

    func testLegendShapeCyclesThroughThreeShapes() {
        XCTAssertEqual(ChartLegendShape.shape(forIndex: 0), .circle)
        XCTAssertEqual(ChartLegendShape.shape(forIndex: 1), .square)
        XCTAssertEqual(ChartLegendShape.shape(forIndex: 2), .triangle)
        XCTAssertEqual(ChartLegendShape.shape(forIndex: 3), .circle, "循环复用")
        XCTAssertEqual(ChartLegendShape.shape(forIndex: -1), .triangle, "负索引也要安全")
    }

    func testSeriesMarkerSymbolsDifferByKind() {
        XCTAssertNotEqual(
            ChartSeriesStyle.markerSymbolName(for: .expenditure),
            ChartSeriesStyle.markerSymbolName(for: .income),
            "R14：两个系列必须能用不同符号区分"
        )
    }

    // MARK: - R16：配色对比度与明度均衡

    /// R16 取舍（用户 2026-09-27 决定）：**保留改版前的原始配色**，不做明度均衡。
    /// 因此这里锁定颜色取值而不是对比度阈值，避免后续被"顺手优化"改成偏暗的色板。
    func testSeriesPaletteKeepsOriginalValues() {
        let expected: [(Double, Double, Double)] = [
            (0.18, 0.60, 1.00), (0.30, 0.78, 0.44), (1.00, 0.60, 0.10), (0.75, 0.35, 1.00),
            (1.00, 0.30, 0.30), (0.10, 0.75, 0.85), (1.00, 0.80, 0.10), (0.55, 0.55, 0.60)
        ]
        XCTAssertEqual(ChartSeriesStyle.seriesLight.count, expected.count, "系列板仍应是 8 色")
        for (index, pair) in expected.enumerated() {
            let rgb = ChartSeriesStyle.seriesLight[index]
            XCTAssertEqual(rgb.red, pair.0, accuracy: 1e-9, "第 \(index) 色被改动")
            XCTAssertEqual(rgb.green, pair.1, accuracy: 1e-9, "第 \(index) 色被改动")
            XCTAssertEqual(rgb.blue, pair.2, accuracy: 1e-9, "第 \(index) 色被改动")
        }
        XCTAssertEqual(ChartSeriesStyle.seriesDark, ChartSeriesStyle.seriesLight, "深浅模式沿用同一组原色")
    }

    func testSemanticColorsKeepOriginalValues() {
        XCTAssertEqual(ChartSeriesStyle.expenseLight, ChartRGB(red: 1.0, green: 0.27, blue: 0.23))
        XCTAssertEqual(ChartSeriesStyle.incomeLight, ChartRGB(red: 0.18, green: 0.78, blue: 0.44))
        XCTAssertEqual(ChartSeriesStyle.expenseDark, ChartSeriesStyle.expenseLight)
        XCTAssertEqual(ChartSeriesStyle.incomeDark, ChartSeriesStyle.incomeLight)
    }

    func testHeatmapRampKeepsOriginalLevels() {
        XCTAssertEqual(HeatmapRamp.light[4], ChartRGB(red: 0.15, green: 0.42, blue: 0.86))
        XCTAssertEqual(HeatmapRamp.light[2], ChartRGB(red: 0.56, green: 0.75, blue: 0.98))
        XCTAssertEqual(HeatmapRamp.dark, HeatmapRamp.light, "默认色阶深浅共用原色（提高对比度变体仅在系统开关下生效）")
    }

    func testHeatmapRampLightnessIsMonotonic() {
        for (name, ramp) in [
            ("light", HeatmapRamp.light),
            ("dark", HeatmapRamp.dark),
            ("lightHighContrast", HeatmapRamp.lightHighContrast),
            ("darkHighContrast", HeatmapRamp.darkHighContrast)
        ] {
            let levels = ramp.dropFirst().map(\.relativeLuminance)
            let ascending = zip(levels, levels.dropFirst()).allSatisfy { $0 < $1 }
            let descending = zip(levels, levels.dropFirst()).allSatisfy { $0 > $1 }
            XCTAssertTrue(ascending || descending, "R16：\(name) 色阶亮度必须单调")
        }
    }

    func testHeatmapTopLevelKeepsContrast() {
        XCTAssertGreaterThanOrEqual(HeatmapRamp.light[4].contrastRatio(against: ChartSeriesStyle.lightCardBackground), 3.0)
        XCTAssertGreaterThanOrEqual(HeatmapRamp.dark[4].contrastRatio(against: ChartSeriesStyle.darkCardBackground), 3.0)
    }

    // MARK: - 辅助

    /// 刻度必须等距，且步长是「整齐数字」（1 / 2 / 2.5 / 5 × 10ⁿ）
    private func assertEvenlySpacedNiceSteps(_ ticks: [Double], label: String) {
        guard ticks.count >= 2 else { return }
        let steps = zip(ticks, ticks.dropFirst()).map { $1 - $0 }
        guard let firstStep = steps.first else { return }
        XCTAssertTrue(isNiceStep(firstStep), "R4：步长 \(firstStep) 不是整齐数字（\(label)）")
        for step in steps {
            XCTAssertEqual(step, firstStep, accuracy: firstStep * 1e-6, "R4：刻度必须等距（\(label)）")
        }
    }

    private func isNiceStep(_ step: Double) -> Bool {
        guard step > 0 else { return false }
        let magnitude = pow(10, (log10(step)).rounded(.down))
        let normalized = step / magnitude
        return [1.0, 2.0, 2.5, 5.0, 10.0].contains { abs($0 - normalized) < 1e-6 }
    }
}
