//
//  CategoryIconTests.swift
//  iFinanceSwiftDataTests
//
//  与主版本同名副本：图标不得重复、SF Symbol 必须存在。
//

import Testing
import UIKit
@testable import iFinanceSwiftData

@MainActor
struct CategoryIconTests {

    @Test
    func expenditureIconsAreUnique() {
        expectUnique(ExpenditureCategory.allCases.map(\.icon), label: "支出")
    }

    @Test
    func incomeIconsAreUnique() {
        expectUnique(IncomeCategory.allCases.map(\.icon), label: "收入")
    }

    @Test
    func allIconsExistInSystemSymbols() {
        for category in ExpenditureCategory.allCases {
            #expect(UIImage(systemName: category.icon) != nil, "支出分类 \(category.rawValue) 的图标 \(category.icon) 不存在")
        }
        for category in IncomeCategory.allCases {
            #expect(UIImage(systemName: category.icon) != nil, "收入分类 \(category.rawValue) 的图标 \(category.icon) 不存在")
        }
    }

    @Test
    func incomeCategoryCount() {
        #expect(IncomeCategory.allCases.count == 12)
        #expect(IncomeCategory(rawValue: "生活费") != nil)
    }

    private func expectUnique(_ icons: [String], label: String) {
        var seen: Set<String> = []
        var duplicates: [String] = []
        for icon in icons where !seen.insert(icon).inserted {
            duplicates.append(icon)
        }
        #expect(duplicates.isEmpty, "\(label)分类存在重复图标：\(duplicates.joined(separator: ", "))")
    }
}
