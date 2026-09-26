//
//  ChartAccessibility.swift
//  iFinance
//
//  R18：Swift Charts 默认已提供逐点无障碍元素与 Audio Graph，这里补「图表标题 + 摘要」，
//  并统一控制每个数据点的朗读标签（上下文在前、数值在后）。
//  R19：轴刻度由各图表的 AxisValueLabel 自行 accessibilityHidden，避免重复朗读。
//
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Accessibility
import Foundation
import SwiftUI


/// SwiftUI 的 `.accessibilityChartDescriptor` 需要 `AXChartDescriptorRepresentable`；
/// `AXChartDescriptor` 本身不符合该协议，因此用这个轻量包装（描述符仍在需要时才构建）。
struct ChartDescriptorRepresentable: AXChartDescriptorRepresentable {
    let builder: () -> AXChartDescriptor

    func makeChartDescriptor() -> AXChartDescriptor { builder() }
}

@MainActor
enum ChartAccessibility {

    // MARK: - 单系列柱状图

    static func barDescriptor(
        title: String,
        summary: String,
        valueLabel: String,
        points: [(date: Date, value: Double)]
    ) -> AXChartDescriptor {
        let timestamps = points.map { $0.date.timeIntervalSince1970 }
        let values = points.map(\.value)
        let lowerX = timestamps.min() ?? 0
        let upperX = max(timestamps.max() ?? lowerX + 1, lowerX + 1)

        let xAxis = AXNumericDataAxisDescriptor(
            title: L10n.string("tendency.a11y.date"),
            range: lowerX...upperX,
            gridlinePositions: []
        ) { value in
            Date(timeIntervalSince1970: value).formatted(date: .abbreviated, time: .omitted)
        }

        let yAxis = AXNumericDataAxisDescriptor(
            title: valueLabel,
            range: 0...max(values.max() ?? 1, 1),
            gridlinePositions: []
        ) { value in
            "\(valueLabel) \(ChartSummary.amount(value))"
        }

        let series = AXDataSeriesDescriptor(
            name: valueLabel,
            isContinuous: false,
            dataPoints: points.map { point in
                AXDataPoint(
                    x: point.date.timeIntervalSince1970,
                    y: point.value,
                    label: String(
                        format: L10n.string("tendency.a11y.point_value"),
                        point.date.formatted(date: .abbreviated, time: .omitted),
                        ChartSummary.amount(point.value)
                    )
                )
            }
        )

        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }

    // MARK: - 双向柱状图（收入 / 支出）

    static func netDescriptor(
        title: String,
        summary: String,
        points: [(date: Date, income: Double, expense: Double)]
    ) -> AXChartDescriptor {
        let timestamps = points.map { $0.date.timeIntervalSince1970 }
        let lowerX = timestamps.min() ?? 0
        let upperX = max(timestamps.max() ?? lowerX + 1, lowerX + 1)
        let maxAmount = max(points.map { max($0.income, $0.expense) }.max() ?? 1, 1)
        let incomeLabel = L10n.string("tendency.net.income")
        let expenseLabel = L10n.string("tendency.net.expense")

        let xAxis = AXNumericDataAxisDescriptor(
            title: L10n.string("tendency.a11y.date"),
            range: lowerX...upperX,
            gridlinePositions: []
        ) { value in
            Date(timeIntervalSince1970: value).formatted(date: .abbreviated, time: .omitted)
        }

        let yAxis = AXNumericDataAxisDescriptor(
            title: L10n.string("tendency.a11y.amount"),
            range: 0...maxAmount,
            gridlinePositions: []
        ) { value in
            "\(L10n.string("tendency.a11y.amount")) \(ChartSummary.amount(value))"
        }

        func label(for date: Date, income: Double, expense: Double) -> String {
            String(
                format: L10n.string("tendency.net.a11y.point"),
                date.formatted(date: .abbreviated, time: .omitted),
                ChartSummary.amount(income),
                ChartSummary.amount(expense)
            )
        }

        let incomeSeries = AXDataSeriesDescriptor(
            name: incomeLabel,
            isContinuous: false,
            dataPoints: points.map {
                AXDataPoint(x: $0.date.timeIntervalSince1970, y: $0.income,
                            label: label(for: $0.date, income: $0.income, expense: $0.expense))
            }
        )
        let expenseSeries = AXDataSeriesDescriptor(
            name: expenseLabel,
            isContinuous: false,
            dataPoints: points.map {
                AXDataPoint(x: $0.date.timeIntervalSince1970, y: -$0.expense,
                            label: label(for: $0.date, income: $0.income, expense: $0.expense))
            }
        )

        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [incomeSeries, expenseSeries]
        )
    }

    // MARK: - 分类占比（饼图 / 环形图）

    static func categoryDescriptor(
        title: String,
        summary: String,
        slices: [(name: String, amount: Double, share: Double)]
    ) -> AXChartDescriptor {
        let categoryAxis = AXCategoricalDataAxisDescriptor(
            title: L10n.string("tendency.a11y.category"),
            categoryOrder: slices.map(\.name)
        )
        let amountAxis = AXNumericDataAxisDescriptor(
            title: L10n.string("tendency.a11y.amount"),
            range: 0...max(slices.map(\.amount).max() ?? 1, 1),
            gridlinePositions: []
        ) { value in
            ChartSummary.amount(value)
        }

        let series = AXDataSeriesDescriptor(
            name: L10n.string("tendency.a11y.amount"),
            isContinuous: false,
            dataPoints: slices.map { slice in
                AXDataPoint(
                    x: slice.name,
                    y: slice.amount,
                    label: String(
                        format: L10n.string("tendency.category.a11y.point"),
                        slice.name,
                        ChartSummary.amount(slice.amount),
                        AppNumberFormat.percent(slice.share)
                    )
                )
            }
        )

        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: categoryAxis,
            yAxis: amountAxis,
            additionalAxes: [],
            series: [series]
        )
    }

    // MARK: - 热力图

    static func heatmapDescriptor(
        title: String,
        summary: String,
        days: [(date: Date, count: Int)]
    ) -> AXChartDescriptor {
        let timestamps = days.map { $0.date.timeIntervalSince1970 }
        let lowerX = timestamps.min() ?? 0
        let upperX = max(timestamps.max() ?? lowerX + 1, lowerX + 1)
        let maxCount = max(days.map(\.count).max() ?? 1, 1)

        let xAxis = AXNumericDataAxisDescriptor(
            title: L10n.string("tendency.a11y.date"),
            range: lowerX...upperX,
            gridlinePositions: []
        ) { value in
            Date(timeIntervalSince1970: value).formatted(date: .abbreviated, time: .omitted)
        }

        let yAxis = AXNumericDataAxisDescriptor(
            title: L10n.string("tendency.heatmap.a11y.count"),
            range: 0...Double(maxCount),
            gridlinePositions: []
        ) { value in
            String(format: L10n.string("tendency.heatmap.a11y.count_format"), Int(value))
        }

        let series = AXDataSeriesDescriptor(
            name: L10n.string("tendency.heatmap.a11y.count"),
            isContinuous: false,
            dataPoints: days.map { day in
                AXDataPoint(
                    x: day.date.timeIntervalSince1970,
                    y: Double(day.count),
                    label: String(
                        format: L10n.string("tendency.heatmap.a11y.point"),
                        day.date.formatted(date: .abbreviated, time: .omitted),
                        day.count
                    )
                )
            }
        )

        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
