//
//  CategoryIconTests.swift
//  iFinanceTests
//
//  图标体系回归：同一类型内图标不得重复，且每个 SF Symbol 必须真实存在。
//  背景：曾经出现「数码 / 通讯」都用 phone、「交通 / 汽车」都用 car 的重复问题。
//

import XCTest
import UIKit
@testable import iFinance

@MainActor
final class CategoryIconTests: XCTestCase {

    func testExpenditureIconsAreUnique() {
        assertUnique(ExpenditureCategory.allCases.map(\.icon), label: "支出")
    }

    func testIncomeIconsAreUnique() {
        assertUnique(IncomeCategory.allCases.map(\.icon), label: "收入")
    }

    func testAllCategoryIconsExistInSystemSymbols() {
        for category in ExpenditureCategory.allCases {
            XCTAssertNotNil(
                UIImage(systemName: category.icon),
                "支出分类「\(category.rawValue)」的图标 \(category.icon) 在当前系统不存在"
            )
        }
        for category in IncomeCategory.allCases {
            XCTAssertNotNil(
                UIImage(systemName: category.icon),
                "收入分类「\(category.rawValue)」的图标 \(category.icon) 在当前系统不存在"
            )
        }
    }

    /// 收入分类新增「生活费」后仍应保持 12 项，避免误删或漏加
    func testIncomeCategoryCount() {
        XCTAssertEqual(IncomeCategory.allCases.count, 12)
        XCTAssertNotNil(IncomeCategory(rawValue: "生活费"))
    }

    private func assertUnique(_ icons: [String], label: String) {
        var seen: Set<String> = []
        var duplicates: [String] = []
        for icon in icons {
            if !seen.insert(icon).inserted {
                duplicates.append(icon)
            }
        }
        XCTAssertTrue(
            duplicates.isEmpty,
            "\(label)分类存在重复图标：\(duplicates.joined(separator: ", "))"
        )
    }
}
