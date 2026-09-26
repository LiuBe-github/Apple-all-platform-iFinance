//
//  ScrubRenderSmokeTests.swift
//  iFinanceTests
//
//  渲染冒烟：把改造后的 scrub 图表托管进 window 并跑一帧，
//  确认 `chartXSelection` + 指示线 + 浮层（ScrubCallout）在运行时可正常渲染。
//

import XCTest
import SwiftUI
@testable import iFinance

@MainActor
final class ScrubRenderSmokeTests: XCTestCase {

    private var window: UIWindow?

    override func tearDownWithError() throws {
        window?.isHidden = true
        window = nil
        try super.tearDownWithError()
    }

    private func render(_ view: some View, size: CGSize = CGSize(width: 360, height: 280)) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        self.window = window
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // 让 SwiftUI 完成一帧渲染（Chart 的 body 会在此求值）
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertGreaterThan(host.view.bounds.width, 0)
    }

    private func makeSeries(days: Int) -> [DailyAmount] {
        let calendar = Calendar.current
        let today = Date().startOfDay
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else { return nil }
            return DailyAmount(date: date, value: Double((offset % 7) * 25))
        }
    }

    /// 单系列柱状图：未选中状态
    func testSingleSeriesChartRendersWithoutSelection() {
        let series = makeSeries(days: 30)
        render(
            TendencyChartView(
                series: series,
                accent: .pink,
                visibleDays: 30,
                isHourly: false,
                scrollBounds: (series.first?.date ?? Date())...(series.last?.date ?? Date()),
                selectedDate: .constant(nil),
                scrollPosition: .constant(series.last?.date ?? Date())
            )
        )
    }

    /// 单系列柱状图：选中状态（会绘制指示线 + 浮层读数）
    func testSingleSeriesChartRendersWithSelection() {
        let series = makeSeries(days: 30)
        let selected = series[20].date
        render(
            TendencyChartView(
                series: series,
                accent: .pink,
                visibleDays: 30,
                isHourly: false,
                scrollBounds: (series.first?.date ?? Date())...(series.last?.date ?? Date()),
                selectedDate: .constant(selected),
                scrollPosition: .constant(series.last?.date ?? Date())
            )
        )
    }

    /// 双向柱状图（总收支）：选中状态（三个读数 + 零轴向下）
    func testNetTrendCardRendersWithSelection() {
        let calendar = Calendar.current
        let today = Date().startOfDay
        let points: [NetTrendPoint] = (0..<12).compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -(11 - offset), to: today) else { return nil }
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
            return NetTrendPoint(date: start, income: Double(1500 + offset * 60), expense: Double(900 + offset * 40))
        }
        render(
            NetTrendCard(
                points: points,
                span: .constant(SpanOption.netOptions.last ?? SpanOption.all[2]),
                scrollPosition: .constant(points.last?.date ?? today),
                selectedDate: .constant(points[8].date)
            )
        )
    }

    /// Dynamic Type 最大档：浮层按可用宽度换行、不因排版高度溢出而崩溃
    func testScrubCalloutRendersAtLargestDynamicType() {
        let series = makeSeries(days: 30)
        render(
            TendencyChartView(
                series: series,
                accent: .pink,
                visibleDays: 30,
                isHourly: false,
                scrollBounds: (series.first?.date ?? Date())...(series.last?.date ?? Date()),
                selectedDate: .constant(series[6].date),
                scrollPosition: .constant(series.last?.date ?? Date())
            )
            .environment(\.dynamicTypeSize, .accessibility5)
        )
    }
}
