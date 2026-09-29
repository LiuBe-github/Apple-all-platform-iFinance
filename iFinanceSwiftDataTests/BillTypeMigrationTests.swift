//
//  BillTypeMigrationTests.swift
//  iFinanceSwiftDataTests
//
//  与主版本同名副本（SwiftData 数据栈）：历史中文类型账单的启动归一化回归。
//

import XCTest
import SwiftData
@testable import iFinanceSwiftData

@MainActor
final class BillTypeMigrationTests: XCTestCase {

    /// 注意：测试夹具必须持有 `PersistenceController`，否则容器会随临时实例释放（insert 直接 SIGTRAP）
    private var controller: PersistenceController!

    override func setUpWithError() throws {
        try super.setUpWithError()
        controller = PersistenceController(inMemory: true)
    }

    override func tearDownWithError() throws {
        controller = nil
        try super.tearDownWithError()
    }

    private var context: ModelContext { controller.container.mainContext }

    private func makeBill(type: String?, amount: Decimal = 100) {
        let bill = Bill(
            amount: amount,
            type: type,
            category: "餐饮",
            note: nil,
            date: Date(),
            createdBy: "migration-test",
            updatedBy: "migration-test"
        )
        context.insert(bill)
    }

    private func allTypes() throws -> [String] {
        try context.fetch(FetchDescriptor<Bill>()).compactMap(\.type).sorted()
    }

    private func netBalance() throws -> Double {
        try context.fetch(FetchDescriptor<Bill>()).reduce(0.0) { total, bill in
            total + BillMath.signedAmount(type: bill.type, amount: bill.amountDouble)
        }
    }

    func testNormalizeLegacyBillTypesRewritesChineseAndGarbageValues() throws {
        makeBill(type: "支出")
        makeBill(type: "收入")
        makeBill(type: "转账")
        makeBill(type: "expenditure")
        makeBill(type: "垃圾值")
        makeBill(type: nil)
        try context.save()

        let changed = controller.normalizeLegacyBillTypes()

        XCTAssertGreaterThan(changed, 0, "中文旧值必须被改写")

        let types = try allTypes()
        XCTAssertEqual(types.count, 6, "所有账单都应拿到非空类型，实际：\(types)")
        XCTAssertTrue(
            types.allSatisfy { ["expenditure", "income", "transfer"].contains($0) },
            "归一化后只允许规范值，实际：\(types)"
        )
        XCTAssertEqual(types.filter { $0 == "income" }.count, 1, "收入应为 1 条，实际：\(types)")
        XCTAssertEqual(types.filter { $0 == "transfer" }.count, 1, "转账应为 1 条，实际：\(types)")
        XCTAssertEqual(controller.normalizeLegacyBillTypes(), 0, "重复执行不应再改写")
    }

    func testNormalizeLegacyBillTypesIsIdempotent() throws {
        makeBill(type: "支出")
        try context.save()

        XCTAssertEqual(controller.normalizeLegacyBillTypes(), 1)
        XCTAssertEqual(controller.normalizeLegacyBillTypes(), 0, "重复执行不应再改写")
    }

    func testLegacyTypeBillContributesToBalanceAsExpense() throws {
        makeBill(type: "支出", amount: 60)
        makeBill(type: "收入", amount: 100)
        try context.save()

        controller.normalizeLegacyBillTypes()

        XCTAssertEqual(try netBalance(), 40, accuracy: 0.0001, "收入 100 − 支出 60 = 40")
    }

    func testTransferDoesNotAffectBalance() throws {
        makeBill(type: "转账", amount: 500)
        makeBill(type: "收入", amount: 20)
        try context.save()

        controller.normalizeLegacyBillTypes()

        XCTAssertEqual(try netBalance(), 20, accuracy: 0.0001, "转账不计入结余")
    }
}
