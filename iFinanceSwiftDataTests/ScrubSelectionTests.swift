//
//  ScrubSelectionTests.swift
//  iFinanceSwiftDataTests
//
//  与主版本同名副本：趋势页 scrub 纯逻辑回归。
//

import Testing
import Foundation
@testable import iFinanceSwiftData

struct ScrubSelectionTests {

    private var calendar: Calendar { .current }

    @Test
    func indexMapsExactDateOnly() {
        let dates = (0..<5).compactMap {
            calendar.date(byAdding: .day, value: $0, to: Date().startOfDay)
        }
        #expect(ScrubSelection.index(of: dates[2], in: dates) == 2)
        #expect(ScrubSelection.index(of: dates[2].addingTimeInterval(3600), in: dates) == nil)
    }

    @Test
    func tickGateCountsSixForSixPoints() {
        var ticks = 0
        var previousIndex: Int?
        for index in 0..<6 {
            if ScrubSelection.shouldTick(from: previousIndex, to: index) { ticks += 1 }
            for _ in 0..<5 where ScrubSelection.shouldTick(from: index, to: index) {
                ticks += 1
            }
            previousIndex = index
        }
        #expect(ticks == 6)
    }

    @Test
    func tickGateIgnoresClearing() {
        #expect(!ScrubSelection.shouldTick(from: 3, to: nil))
        #expect(!ScrubSelection.shouldTick(from: nil, to: nil))
        #expect(ScrubSelection.shouldTick(from: nil, to: 0))
    }

    @Test
    func edgeHold() {
        #expect(ScrubSelection.edgeHold(index: 0, count: 10) == -1)
        #expect(ScrubSelection.edgeHold(index: 9, count: 10) == 1)
        #expect(ScrubSelection.edgeHold(index: 5, count: 10) == 0)
        #expect(ScrubSelection.edgeHold(index: nil, count: 10) == 0)
    }
}
