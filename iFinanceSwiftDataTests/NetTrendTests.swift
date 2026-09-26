//
//  NetTrendTests.swift
//  iFinanceSwiftDataTests
//
//  与主版本同名副本：总收支双向柱状图的聚合回归。
//

import Testing
import Foundation
@testable import iFinanceSwiftData

@MainActor
struct NetTrendTests {

    private var calendar: Calendar { .current }

    @Test
    func dailyBuckets() {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entries: [(date: Date, type: String, amount: Double)] = [
            (date: today.addingTimeInterval(3600), type: "income", amount: 100),
            (date: today.addingTimeInterval(7200), type: "expenditure", amount: 40),
            (date: yesterday, type: "transfer", amount: 999)
        ]
        let points = NetTrendBuilder.series(entries: entries, spanDays: 30, now: now, calendar: calendar)
        let todayPoint = points.first { $0.date == today }
        #expect(todayPoint?.income == 100)
        #expect(todayPoint?.expense == 40)
        #expect(todayPoint?.net == 60)
        #expect(points.first { $0.date == yesterday }?.income == 0)
    }

    @Test
    func monthlyBuckets() {
        let points = NetTrendBuilder.series(entries: [], spanDays: 180)
        #expect(points.count == 25)
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))
        #expect(points.last?.date == currentMonth)
    }
}
