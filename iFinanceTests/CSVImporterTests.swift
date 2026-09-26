//
//  CSVImporterTests.swift
//  iFinanceTests
//

import XCTest
@testable import iFinance
import CoreData

@MainActor
final class CSVImporterTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        UserDefaults.standard.set("csv_test@example.com", forKey: "AuthUserIdentifier")
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "AuthUserIdentifier")
        context = nil
        persistenceController = nil
        try super.tearDownWithError()
    }

    // MARK: - 行解析

    func testParseRowsHandlesQuotesEscapesAndCRLF() {
        let input = "date,type,category,amount,note\r\n2026-09-01 10:00:00,expenditure,餐饮,12.50,\"含,逗号\"\r\n2026-09-02 11:00:00,income,工资,100,\"引号\"\"转义\"\r\n\r\n"
        let rows = CSVImporter.parseRows(input)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[1][4], "含,逗号")
        XCTAssertEqual(rows[2][4], "引号\"转义")
        XCTAssertEqual(rows[2][3], "100")
    }

    /// 本 App 自己导出的 CSV 用 LF 换行，必须仍能解析（回归：CRLF 修复不能反向破坏 LF）
    func testParseRowsHandlesLFOnlyExport() {
        let input = "date,type,category,amount,note\n2026-09-01 10:00:00,expenditure,餐饮,12.50,午餐\n2026-09-02 11:00:00,income,工资,100,\n"
        let rows = CSVImporter.parseRows(input)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[1][3], "12.50")
        XCTAssertEqual(rows[2][4], "")
    }

    // MARK: - 非法行

    func testMakeBillRejectsInvalidRows() {
        let identifier = "csv_test@example.com"
        XCTAssertNil(CSVImporter.makeBill(row: ["2026-09-01"], context: context, identifier: identifier)) // 列数不足
        XCTAssertNil(CSVImporter.makeBill(row: ["2026-09-01 10:00:00", "grocery", "餐饮", "12.5", ""], context: context, identifier: identifier)) // 非法 type
        XCTAssertNil(CSVImporter.makeBill(row: ["2026-09-01 10:00:00", "expenditure", "餐饮", "abc", ""], context: context, identifier: identifier)) // 非法金额
    }

    // MARK: - POSIX 金额解析（钉住 en_US_POSIX 拼写回归）

    func testMakeBillParsesPOSIXDecimal() {
        let bill = CSVImporter.makeBill(
            row: ["2026-09-01 10:00:00", "expenditure", "餐饮", "12.50", "午餐"],
            context: context,
            identifier: "csv_test@example.com"
        )
        XCTAssertEqual(bill?.amount?.decimalValue, Decimal(string: "12.5"))
    }

    // MARK: - 核心回归：导入的账单对当前账号可见

    func testImportedBillVisibleViaUserPredicate() throws {
        let bill = CSVImporter.makeBill(
            row: ["2026-09-01T10:00:00Z", "income", "工资", "100", "九月工资"],
            context: context,
            identifier: "csv_test@example.com"
        )
        XCTAssertNotNil(bill)
        XCTAssertNotNil(bill?.id)
        XCTAssertNotNil(bill?.createdAt)
        XCTAssertNotNil(bill?.updatedAt)
        XCTAssertEqual(bill?.createdBy, "csv_test@example.com")
        XCTAssertEqual(bill?.updatedBy, "csv_test@example.com")
        try context.save()

        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = PersistenceController.billUserPredicate
        let visible = try context.fetch(request)
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.note, "九月工资")
    }
}
