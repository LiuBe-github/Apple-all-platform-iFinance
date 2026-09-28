//
//  BillInputTests.swift
//  iFinanceTests
//
//  回归：编辑账单时「类型归一化」与「金额输入归一化」。
//  历史数据里 `Bill.type` 可能是模型默认值「支出」等中文，若不归一化，
//  编辑页的类型分段与分类校验都会失败（保存按钮点了没反应 → 金额改不动）。
//

import XCTest
@testable import iFinanceSwiftData

@MainActor
final class BillInputTests: XCTestCase {

    // MARK: - 类型归一化

    func testNormalizedTypeMapsLegacyChineseValues() {
        XCTAssertEqual(BillEditRules.normalizedType("支出"), "expenditure")
        XCTAssertEqual(BillEditRules.normalizedType("收入"), "income")
        XCTAssertEqual(BillEditRules.normalizedType("转账"), "transfer")
    }

    func testNormalizedTypeKeepsCanonicalValuesAndFallsBack() {
        XCTAssertEqual(BillEditRules.normalizedType("expenditure"), "expenditure")
        XCTAssertEqual(BillEditRules.normalizedType("income"), "income")
        XCTAssertEqual(BillEditRules.normalizedType("transfer"), "transfer")
        XCTAssertEqual(BillEditRules.normalizedType(nil), "expenditure")
        XCTAssertEqual(BillEditRules.normalizedType("乱七八糟"), "expenditure")
    }

    /// 修复点：中文类型的账单归一化后，分类校验必须通过（否则保存按钮永远禁用）
    func testLegacyTypeBillPassesCategoryValidationAfterNormalizing() {
        let legacyType = "支出"
        XCTAssertFalse(BillEditRules.isValid("餐饮", for: legacyType), "归一化前解析不出分类类型")
        XCTAssertTrue(BillEditRules.isValid("餐饮", for: BillEditRules.normalizedType(legacyType)))
    }

    // MARK: - 金额输入归一化

    func testAmountInputNormalizesFullWidthAndSeparators() {
        XCTAssertEqual(BillAmountInput.normalize("１２３．４５"), "123.45")
        XCTAssertEqual(BillAmountInput.normalize("12。5"), "12.5")
        XCTAssertEqual(BillAmountInput.normalize("1,234.5"), "1234.5")
        XCTAssertEqual(BillAmountInput.normalize("￥123"), "123")
    }

    func testAmountInputKeepsOnlyFirstDecimalPoint() {
        XCTAssertEqual(BillAmountInput.normalize("12.3.4"), "12.34")
    }

    func testAmountValueParsing() {
        XCTAssertEqual(BillAmountInput.value("１２．５") ?? 0, 12.5, accuracy: 0.0001)
        XCTAssertEqual(BillAmountInput.value("88"), 88)
        XCTAssertNil(BillAmountInput.value(""))
        XCTAssertNil(BillAmountInput.value("abc"))
        XCTAssertNil(BillAmountInput.value("-"))
    }
}
