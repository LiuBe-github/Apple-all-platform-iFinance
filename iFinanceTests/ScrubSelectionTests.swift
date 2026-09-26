//
//  ScrubSelectionTests.swift
//  iFinanceTests
//
//  趋势页 scrub（按住扫读）纯逻辑回归：下标映射、触觉门控、贴边判定。
//

import XCTest
@testable import iFinance

final class ScrubSelectionTests: XCTestCase {

    private let calendar = Calendar.current

    func testIndexMapsExactDateOnly() {
        let dates = (0..<5).compactMap {
            calendar.date(byAdding: .day, value: $0, to: Date().startOfDay)
        }
        XCTAssertEqual(ScrubSelection.index(of: dates[2], in: dates), 2)
        // 原生 chartXSelection 已吸附到数据点；非数据点时刻不应命中
        XCTAssertNil(ScrubSelection.index(of: dates[2].addingTimeInterval(3600), in: dates))
    }

    /// 契约「扫过 6 个数据点 = 6 次触觉」：连续进入 6 个新点 → 恰好 6 次；
    /// 同一数据点内的重复回调不再触发（不是每帧触发）。
    func testTickGateCountsSixForSixPoints() {
        var ticks = 0
        var previousIndex: Int?
        for index in 0..<6 {
            if ScrubSelection.shouldTick(from: previousIndex, to: index) { ticks += 1 }
            for _ in 0..<5 where ScrubSelection.shouldTick(from: index, to: index) {
                ticks += 1
            }
            previousIndex = index
        }
        XCTAssertEqual(ticks, 6, "扫过 6 个数据点应恰好 6 次 tick")
    }

    func testTickGateIgnoresClearing() {
        XCTAssertFalse(ScrubSelection.shouldTick(from: 3, to: nil), "松手清空不应触发触觉")
        XCTAssertFalse(ScrubSelection.shouldTick(from: nil, to: nil))
        XCTAssertTrue(ScrubSelection.shouldTick(from: nil, to: 0), "首次进入数据点应触发一次")
    }

    func testEdgeHold() {
        XCTAssertEqual(ScrubSelection.edgeHold(index: 0, count: 10), -1)
        XCTAssertEqual(ScrubSelection.edgeHold(index: 9, count: 10), 1)
        XCTAssertEqual(ScrubSelection.edgeHold(index: 5, count: 10), 0)
        XCTAssertEqual(ScrubSelection.edgeHold(index: nil, count: 10), 0)
        XCTAssertEqual(ScrubSelection.edgeHold(index: 0, count: 1), 0, "单点窗口没有可滚动空间")
    }
}
