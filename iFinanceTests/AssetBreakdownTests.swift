//
//  AssetBreakdownTests.swift
//  iFinanceTests
//
//  M1 纯逻辑回归：资产总额 / 负债 / 类型占比 / 快照差值 / 同日 upsert。
//

import XCTest
@testable import iFinance

final class AssetBreakdownTests: XCTestCase {

    private func account(
        _ name: String,
        type: AssetType,
        balance: Double,
        include: Bool = true
    ) -> AssetAccountSnapshot {
        AssetAccountSnapshot(
            id: UUID(),
            name: name,
            type: type,
            balance: balance,
            note: nil,
            includeInTotal: include,
            sortOrder: 0
        )
    }

    func testTotalsExcludeNegativeAndExcludedAccounts() {
        let accounts = [
            account("现金", type: .cash, balance: 1_000),
            account("储蓄卡", type: .debitCard, balance: 5_000),
            account("信用卡", type: .creditCard, balance: -2_000),
            account("不计入", type: .other, balance: 9_999, include: false)
        ]
        XCTAssertEqual(AssetBreakdown.totalAssets(accounts), 6_000, accuracy: 0.001)
        XCTAssertEqual(AssetBreakdown.totalLiabilities(accounts), 2_000, accuracy: 0.001)
        XCTAssertEqual(AssetBreakdown.netTotal(accounts), 4_000, accuracy: 0.001)
    }

    func testBreakdownKeepsFixedTypeOrderAndSkipsNonPositive() {
        let accounts = [
            account("股票", type: .investment, balance: 20_000),
            account("现金", type: .cash, balance: 1_000),
            account("空账户", type: .payment, balance: 0),
            account("信用卡", type: .creditCard, balance: -2_000),
            account("隐藏", type: .other, balance: 500, include: false)
        ]
        let slices = AssetBreakdown.breakdown(accounts)
        XCTAssertEqual(slices.map(\.type), [.cash, .investment], "按固定类型顺序，且跳过 0 / 负数 / 不计入")
        XCTAssertEqual(slices.reduce(0) { $0 + $1.amount }, 21_000, accuracy: 0.001)
        XCTAssertEqual(slices.reduce(0) { $0 + $1.share }, 1.0, accuracy: 0.0001, "占比合计为 1")
    }

    func testBreakdownEmptyWhenNoPositiveAssets() {
        let accounts = [account("信用卡", type: .creditCard, balance: -2_000)]
        XCTAssertTrue(AssetBreakdown.breakdown(accounts).isEmpty)
    }

    func testSnapshotChange() {
        let previous = AssetSnapshotValue(date: Date().addingTimeInterval(-86_400), totalAssets: 10_000, totalLiabilities: 2_000)
        let current = AssetSnapshotValue(date: Date(), totalAssets: 12_000, totalLiabilities: 2_000)
        let change = AssetBreakdown.change(current: current, previous: previous)
        XCTAssertEqual(change?.amount ?? 0, 2_000, accuracy: 0.001)
        XCTAssertEqual(change?.ratio ?? 0, 0.25, accuracy: 0.0001, "较上次 +25%")
        XCTAssertNil(AssetBreakdown.change(current: current, previous: nil), "只有一条快照时没有「较上次」")
    }

    func testSnapshotChangeRatioNilWhenPreviousNetIsZero() {
        let previous = AssetSnapshotValue(date: Date().addingTimeInterval(-86_400), totalAssets: 5_000, totalLiabilities: 5_000)
        let current = AssetSnapshotValue(date: Date(), totalAssets: 6_000, totalLiabilities: 5_000)
        let change = AssetBreakdown.change(current: current, previous: previous)
        XCTAssertEqual(change?.amount ?? 0, 1_000, accuracy: 0.001)
        XCTAssertNil(change?.ratio, "上一次净额为 0 时只给差值")
    }

    func testUpsertIndexMatchesSameDay() {
        let today = Date()
        let snapshots = [
            AssetSnapshotValue(date: today.addingTimeInterval(-86_400 * 2), totalAssets: 1, totalLiabilities: 0),
            AssetSnapshotValue(date: today.addingTimeInterval(-60), totalAssets: 2, totalLiabilities: 0)
        ]
        XCTAssertEqual(AssetBreakdown.upsertIndex(for: today, in: snapshots), 1, "同日应命中第二条（覆盖写）")
        XCTAssertNil(AssetBreakdown.upsertIndex(for: today.addingTimeInterval(86_400 * 5), in: snapshots))
    }
}
