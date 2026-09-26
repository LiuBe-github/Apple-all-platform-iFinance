//
//  CategoryStoreTests.swift
//  iFinanceSwiftDataTests
//
//  与主版本同名副本：自定义分类 / 二级分类的存储与解析回归。
//

import Testing
import UIKit
@testable import iFinanceSwiftData

@MainActor
struct CategoryStoreTests {

    private var store: CategoryStore { CategoryStore.shared }
    private var defaults: UserDefaults { .standard }

    private var account: String { AuthManager.shared.userIdentifier }
    private var storageKey: String { "custom_categories_v1_\(account)" }
    private var seedKey: String { "custom_categories_seeded_v1_\(account)" }

    private func reset() {
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: seedKey)
        store.reload(force: true)
    }

    @Test
    func seedCreatesTrafficSubcategories() {
        reset()
        defer { reset() }
        let trafficKey = ExpenditureCategory.traffic.rawValue
        let subs = store.subcategories(parentKey: trafficKey, kind: .expenditure)
        #expect(subs.count == CategoryStore.trafficSubcategoryPresets.count)
        #expect(subs.first?.icon == "bus")
    }

    @Test
    func addValidateAndResolve() throws {
        reset()
        defer { reset() }
        let item = try store.add(kind: .expenditure, name: "咖啡", icon: "cup.and.saucer", colorHex: nil, parentKey: nil)
        #expect(store.topLevel(.expenditure).contains { $0.id == item.id })
        #expect(CategoryResolver.isValid("咖啡", kind: .expenditure))
        #expect(CategoryResolver.icon(for: "咖啡", kind: .expenditure) == "cup.and.saucer")
        #expect(throws: CategoryStoreError.self) {
            _ = try store.add(kind: .expenditure, name: "咖啡", icon: "tag", colorHex: nil, parentKey: nil)
        }
        #expect(throws: CategoryStoreError.self) {
            _ = try store.add(kind: .expenditure, name: "餐饮", icon: "tag", colorHex: nil, parentKey: nil)
        }
    }

    @Test
    func subcategoryPathAndRename() throws {
        reset()
        defer { reset() }
        let parent = try store.add(kind: .income, name: "理财", icon: "chart.pie", colorHex: nil, parentKey: nil)
        let sub = try store.add(kind: .income, name: "基金", icon: "chart.line.uptrend.xyaxis", colorHex: nil, parentKey: parent.key)
        #expect(store.storedPath(of: sub) == "理财/基金")
        #expect(CategoryResolver.isValid("理财/基金", kind: .income))
        #expect(CategoryResolver.parentRaw("理财/基金") == "理财")

        try store.update(id: sub.id, name: "股票", icon: "chart.line.uptrend.xyaxis", colorHex: nil)
        let renamed = store.item(id: sub.id)
        #expect(renamed?.name == "股票")
        #expect(store.storedPath(of: renamed!) == "理财/股票")
    }

    @Test
    func deleteRemovesFromPickerButKeepsRawName() throws {
        reset()
        defer { reset() }
        let item = try store.add(kind: .expenditure, name: "订阅", icon: "repeat", colorHex: nil, parentKey: nil)
        store.delete(id: item.id)
        #expect(!CategoryResolver.isValid("订阅", kind: .expenditure))
        #expect(CategoryResolver.displayName(for: "订阅", kind: .expenditure) == "订阅")
    }
}
