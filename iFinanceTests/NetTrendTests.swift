//
//  NetTrendTests.swift
//  iFinanceTests
//
//  总收支双向柱状图的聚合回归（按天 / 按月、转账不计入）。
//

import XCTest
@testable import iFinance

@MainActor
final class NetTrendTests: XCTestCase {

    private let calendar = Calendar.current

    func testDailyBucketsSeparateIncomeAndExpense() {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let entries: [(date: Date, type: String, amount: Double)] = [
            (date: today.addingTimeInterval(3600), type: "income", amount: 100),
            (date: today.addingTimeInterval(7200), type: "expenditure", amount: 40),
            (date: yesterday.addingTimeInterval(3600), type: "income", amount: 20),
            // 转账必须被忽略
            (date: yesterday.addingTimeInterval(3600), type: "transfer", amount: 999)
        ]

        let points = NetTrendBuilder.series(entries: entries, spanDays: 30, now: now, calendar: calendar)

        let todayPoint = points.first { $0.date == today }
        XCTAssertEqual(todayPoint?.income ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(todayPoint?.expense ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(todayPoint?.net ?? 0, 60, accuracy: 0.001)

        let yesterdayPoint = points.first { $0.date == yesterday }
        XCTAssertEqual(yesterdayPoint?.income ?? 0, 20, accuracy: 0.001)
        XCTAssertEqual(yesterdayPoint?.expense ?? 0, 0, accuracy: 0.001)
    }

    func testDailySeriesCoversEnoughHistoryForScrolling() {
        let points = NetTrendBuilder.series(entries: [], spanDays: 30)
        XCTAssertEqual(points.count, 395)
        XCTAssertEqual(points.last?.date, calendar.startOfDay(for: Date()))
    }

    func testMonthlyBucketsForSixMonthsSpan() {
        let points = NetTrendBuilder.series(entries: [], spanDays: 180)
        XCTAssertEqual(points.count, 25)
        for point in points {
            XCTAssertEqual(calendar.component(.day, from: point.date), 1)
        }
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))
        XCTAssertEqual(points.last?.date, currentMonth)
    }

    func testMonthlyAggregationForYearSpan() {
        let now = Date()
        let entries: [(date: Date, type: String, amount: Double)] = [
            (date: now, type: "income", amount: 500),
            (date: now, type: "expenditure", amount: 200),
            (date: now.addingTimeInterval(-86_400 * 3), type: "expenditure", amount: 100)
        ]
        let points = NetTrendBuilder.series(entries: entries, spanDays: 365, now: now, calendar: calendar)
        XCTAssertEqual(points.count, 25)
        XCTAssertEqual(points.last?.income ?? 0, 500, accuracy: 0.001)
        XCTAssertEqual(points.last?.expense ?? 0, 300, accuracy: 0.001)
        XCTAssertEqual(points.last?.net ?? 0, 200, accuracy: 0.001)
    }
}
