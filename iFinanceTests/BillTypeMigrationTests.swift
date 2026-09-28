//
//  BillTypeMigrationTests.swift
//  iFinanceTests
//
//  回归：历史账单里的中文类型（模型旧默认值「支出」等）在启动归一化后被改写。
//  修复前这类账单被当成收入：当日结余算错、编辑页保存被静默拦下（分类校验永远失败）。
//

import XCTest
import CoreData
@testable import iFinance

@MainActor
final class BillTypeMigrationTests: XCTestCase {

    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        persistence = nil
        try super.tearDownWithError()
    }

    private func makeBill(type: String?, amount: Double = 100) {
        let bill = Bill(context: context)
        bill.id = UUID()
        bill.amount = NSDecimalNumber(value: amount)
        bill.type = type
        bill.category = "餐饮"
        bill.date = Date()
        bill.createdAt = Date()
        bill.updatedAt = Date()
        bill.createdBy = "migration-test"
        bill.updatedBy = "migration-test"
    }

    private func allTypes() throws -> [String] {
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        return try context.fetch(request).compactMap(\.type).sorted()
    }

    private func netBalance() throws -> Double {
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        return try context.fetch(request).reduce(0.0) { total, bill in
            total + BillMath.signedAmount(type: bill.type, amount: bill.amount?.doubleValue ?? 0)
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

        let changed = PersistenceController.normalizeLegacyBillTypes(in: context)

        XCTAssertGreaterThan(changed, 0, "中文旧值必须被改写")

        let types = try allTypes()
        XCTAssertEqual(types.count, 6, "所有账单都应拿到非空类型，实际：\(types)")
        XCTAssertTrue(
            types.allSatisfy { ["expenditure", "income", "transfer"].contains($0) },
            "归一化后只允许规范值，实际：\(types)"
        )
        XCTAssertEqual(types.filter { $0 == "income" }.count, 1, "收入应为 1 条，实际：\(types)")
        XCTAssertEqual(types.filter { $0 == "transfer" }.count, 1, "转账应为 1 条，实际：\(types)")
        XCTAssertEqual(PersistenceController.normalizeLegacyBillTypes(in: context), 0, "重复执行不应再改写")
    }

    func testNormalizeLegacyBillTypesIsIdempotent() throws {
        makeBill(type: "支出")
        try context.save()

        XCTAssertEqual(PersistenceController.normalizeLegacyBillTypes(in: context), 1)
        XCTAssertEqual(PersistenceController.normalizeLegacyBillTypes(in: context), 0, "重复执行不应再改写")
    }

    func testLegacyTypeBillContributesToBalanceAsExpense() throws {
        makeBill(type: "支出", amount: 60)
        makeBill(type: "收入", amount: 100)
        try context.save()

        PersistenceController.normalizeLegacyBillTypes(in: context)

        XCTAssertEqual(try netBalance(), 40, accuracy: 0.0001, "收入 100 − 支出 60 = 40")
    }

    func testTransferDoesNotAffectBalance() throws {
        makeBill(type: "转账", amount: 500)
        makeBill(type: "收入", amount: 20)
        try context.save()

        PersistenceController.normalizeLegacyBillTypes(in: context)

        XCTAssertEqual(try netBalance(), 20, accuracy: 0.0001, "转账不计入结余")
    }
}
