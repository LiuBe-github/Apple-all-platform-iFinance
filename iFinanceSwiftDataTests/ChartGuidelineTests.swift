//
//  ChartGuidelineTests.swift
//  iFinanceSwiftDataTests
//
//  与主版本同名副本：图表规范（R1–R22）纯逻辑回归。
//

import Testing
import Foundation
import SwiftUI
@testable import iFinanceSwiftData

struct ChartGuidelineTests {

    // MARK: - R2 / R3 / R4

    @Test
    func barAxisStartsAtZeroAndCoversData() {
        for maxValue in [1.0, 3, 7, 99, 1234, 12345] {
            let model = ChartAxisSupport.barAxis(maxValue: maxValue)
            #expect(model.domain.lowerBound == 0)
            #expect(model.domain.upperBound >= maxValue)
            #expect((3...5).contains(model.ticks.count))
        }
    }

    @Test
    func bidirectionalAxisCrossesZero() {
        let model = ChartAxisSupport.bidirectionalAxis(minValue: -40, maxValue: 100)
        #expect(model.domain.lowerBound < 0)
        #expect(model.domain.upperBound > 0)
        #expect(model.ticks.contains(0))
    }

    // MARK: - R6

    @Test
    func compactAmount() {
        #expect(ChartAxisSupport.compactAmount(3500, usesTenThousandUnit: true) == "3500")
        #expect(ChartAxisSupport.compactAmount(12_300, usesTenThousandUnit: true) == "1.2万")
        #expect(ChartAxisSupport.compactAmount(123_000, usesTenThousandUnit: true) == "12万")
        #expect(ChartAxisSupport.compactAmount(12_300, usesTenThousandUnit: false) == "12k")
        #expect(ChartAxisSupport.compactAmount(0.25, usesTenThousandUnit: true) == "0.25")
        #expect(ChartAxisSupport.compactAmount(0.5, usesTenThousandUnit: true) == "0.5")
    }

    // MARK: - R7

    @Test
    func subtitleContainsConclusion() {
        let text = ChartSummary.periodSubtitle(rangeText: "6月1日 – 6月30日", total: 2340, average: 78)
        #expect(text.contains(L10n.string("chart.summary.total")))
        #expect(text.contains(L10n.string("chart.summary.average")))
        #expect(ChartSummary.netSubtitle(rangeText: "6月", net: 520).contains("+520"))
    }

    // MARK: - R14

    @Test
    func shapesAndSymbolsDiffer() {
        #expect(ChartLegendShape.shape(forIndex: 0) == .circle)
        #expect(ChartLegendShape.shape(forIndex: 1) == .square)
        #expect(ChartLegendShape.shape(forIndex: 2) == .triangle)
        #expect(ChartSeriesStyle.markerSymbolName(for: .expenditure) != ChartSeriesStyle.markerSymbolName(for: .income))
    }

    // MARK: - R16

    @Test
    func colorsMeetContrastAndBalance() {
        for rgb in ChartSeriesStyle.seriesLight {
            #expect(rgb.contrastRatio(against: ChartSeriesStyle.lightCardBackground) >= 3.0)
        }
        for rgb in ChartSeriesStyle.seriesDark {
            #expect(rgb.contrastRatio(against: ChartSeriesStyle.darkCardBackground) >= 3.0)
        }
        let light = ChartSeriesStyle.seriesLight.map(\.relativeLuminance)
        let dark = ChartSeriesStyle.seriesDark.map(\.relativeLuminance)
        #expect((light.max() ?? 0) - (light.min() ?? 0) < 0.10)
        #expect((dark.max() ?? 0) - (dark.min() ?? 0) < 0.10)
    }

    @Test
    func heatmapRampIsMonotonic() {
        for ramp in [HeatmapRamp.light, HeatmapRamp.dark, HeatmapRamp.lightHighContrast, HeatmapRamp.darkHighContrast] {
            let levels = ramp.dropFirst().map(\.relativeLuminance)
            let ascending = zip(levels, levels.dropFirst()).allSatisfy { $0 < $1 }
            let descending = zip(levels, levels.dropFirst()).allSatisfy { $0 > $1 }
            #expect(ascending || descending)
        }
        #expect(HeatmapRamp.light[4].contrastRatio(against: ChartSeriesStyle.lightCardBackground) >= 3.0)
        #expect(HeatmapRamp.dark[4].contrastRatio(against: ChartSeriesStyle.darkCardBackground) >= 3.0)
    }
}
