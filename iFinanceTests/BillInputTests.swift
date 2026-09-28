//
//  BillInputTests.swift
//  iFinanceTests
//
//  回归：编辑账单时「类型归一化」与「金额输入归一化」。
//  历史数据里 `Bill.type` 可能是模型默认值「支出」等中文，若不归一化，
//  编辑页的类型分段与分类校验都会失败（保存按钮点了没反应 → 金额改不动）。
//

import XCTest
@testable import iFinance

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

    // MARK: - 统一口径（BillMath）

    func testBillMathSignedAmountHandlesLegacyAndCanonicalTypes() {
        XCTAssertEqual(BillMath.signedAmount(type: "expenditure", amount: 100), -100)
        XCTAssertEqual(BillMath.signedAmount(type: "支出", amount: 100), -100, "历史中文类型必须按支出算")
        XCTAssertEqual(BillMath.signedAmount(type: "income", amount: 30), 30)
        XCTAssertEqual(BillMath.signedAmount(type: "收入", amount: 30), 30)
        XCTAssertEqual(BillMath.signedAmount(type: "transfer", amount: 999), 0, "转账不计入结余")
        XCTAssertEqual(BillMath.signedAmount(type: "转账", amount: 999), 0)
        XCTAssertEqual(BillMath.signedAmount(type: nil, amount: 12), -12, "未知类型按支出处理")
        XCTAssertEqual(BillMath.signedAmount(type: "乱写", amount: 12), -12)
    }

    func testBillMathTypeHelpers() {
        XCTAssertTrue(BillMath.isExpenditure("支出"))
        XCTAssertTrue(BillMath.isIncome("收入"))
        XCTAssertTrue(BillMath.isTransfer("转账"))
        XCTAssertFalse(BillMath.isExpenditure("income"))

        XCTAssertFalse(BillMath.countsInTotals("transfer"))
        XCTAssertFalse(BillMath.countsInTotals("转账"))
        XCTAssertTrue(BillMath.countsInTotals("支出"))
        XCTAssertTrue(BillMath.countsInTotals("income"))
    }

    func testNeedsNormalizationAndCanonicalType() {
        XCTAssertTrue(BillEditRules.needsNormalization("支出"))
        XCTAssertTrue(BillEditRules.needsNormalization(nil))
        XCTAssertTrue(BillEditRules.needsNormalization("垃圾值"))
        XCTAssertFalse(BillEditRules.needsNormalization("expenditure"))
        XCTAssertFalse(BillEditRules.needsNormalization("income"))
        XCTAssertFalse(BillEditRules.needsNormalization("transfer"))

        XCTAssertNil(BillEditRules.canonicalType("垃圾值"))
        XCTAssertEqual(BillEditRules.normalizedType("垃圾值"), "expenditure")
        XCTAssertEqual(BillEditRules.canonicalType("转账"), "transfer")
    }
}
