//
//  CategoryStoreTests.swift
//  iFinanceTests
//
//  自定义分类 / 二级分类的存储与解析回归。
//

import XCTest
import UIKit
@testable import iFinance

@MainActor
final class CategoryStoreTests: XCTestCase {

    private let store = CategoryStore.shared
    private let defaults = UserDefaults.standard

    private var account: String { AuthManager.shared.userIdentifier }
    private var storageKey: String { "custom_categories_v1_\(account)" }
    private var seedKey: String { "custom_categories_seeded_v1_\(account)" }

    override func setUpWithError() throws {
        try super.setUpWithError()
        cleanStorage()
        store.reload(force: true)
    }

    override func tearDownWithError() throws {
        cleanStorage()
        store.reload(force: true)
        try super.tearDownWithError()
    }

    private func cleanStorage() {
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: seedKey)
    }

    // MARK: - 播种

    func testSeedCreatesTrafficSubcategories() {
        let trafficKey = ExpenditureCategory.traffic.rawValue
        let subs = store.subcategories(parentKey: trafficKey, kind: .expenditure)
        XCTAssertEqual(subs.count, CategoryStore.trafficSubcategoryPresets.count)
        XCTAssertEqual(subs.first?.icon, "bus")
        XCTAssertNotNil(subs.first?.builtInKey)
    }

    // MARK: - 新增与校验

    func testAddCustomCategory() throws {
        let item = try store.add(kind: .expenditure, name: "咖啡", icon: "cup.and.saucer", colorHex: "#2E9BFF", parentKey: nil)
        XCTAssertEqual(item.name, "咖啡")
        XCTAssertTrue(store.topLevel(.expenditure).contains { $0.id == item.id })
        XCTAssertEqual(CategoryResolver.displayName(for: "咖啡", kind: .expenditure), "咖啡")
        XCTAssertEqual(CategoryResolver.icon(for: "咖啡", kind: .expenditure), "cup.and.saucer")
    }

    func testRejectsInvalidNames() throws {
        XCTAssertThrowsError(try store.add(kind: .expenditure, name: "   ", icon: "tag", colorHex: nil, parentKey: nil))
        XCTAssertThrowsError(try store.add(kind: .expenditure, name: "超过八个字的名字啊", icon: "tag", colorHex: nil, parentKey: nil))
        XCTAssertThrowsError(try store.add(kind: .expenditure, name: "咖啡/奶茶", icon: "tag", colorHex: nil, parentKey: nil))
        // 与内置分类重名
        XCTAssertThrowsError(try store.add(kind: .expenditure, name: "餐饮", icon: "tag", colorHex: nil, parentKey: nil))
        // 同类型重名
        _ = try store.add(kind: .expenditure, name: "咖啡", icon: "tag", colorHex: nil, parentKey: nil)
        XCTAssertThrowsError(try store.add(kind: .expenditure, name: "咖啡", icon: "star", colorHex: nil, parentKey: nil))
    }

    func testIconOccupancy() throws {
        let item = try store.add(kind: .income, name: "报销", icon: "doc.text", colorHex: nil, parentKey: nil)
        let taken = store.takenIcons(kind: .income, parentKey: nil)
        XCTAssertTrue(taken.contains("doc.text"))
        // 收入内置图标也算已占用
        XCTAssertTrue(taken.contains(IncomeCategory.salary.icon))
        store.delete(id: item.id)
        XCTAssertFalse(store.takenIcons(kind: .income, parentKey: nil).contains("doc.text"))
    }

    // MARK: - 二级分类

    func testCustomSubcategoryPathAndAggregation() throws {
        let parent = try store.add(kind: .expenditure, name: "宠物用品", icon: "pawprint", colorHex: nil, parentKey: nil)
        _ = try store.add(kind: .expenditure, name: "猫粮", icon: "fish", colorHex: nil, parentKey: parent.key)

        let path = "宠物用品/猫粮"
        XCTAssertTrue(CategoryResolver.isValid(path, kind: .expenditure))
        XCTAssertEqual(CategoryResolver.parentRaw(path), "宠物用品")
        XCTAssertEqual(CategoryResolver.icon(for: path, kind: .expenditure), "fish")
        XCTAssertTrue(CategoryResolver.displayName(for: path, kind: .expenditure).contains("猫粮"))
    }

    func testSubcategoryStoredPath() throws {
        let parent = try store.add(kind: .income, name: "理财", icon: "chart.pie", colorHex: nil, parentKey: nil)
        let sub = try store.add(kind: .income, name: "基金", icon: "chart.line.uptrend.xyaxis", colorHex: nil, parentKey: parent.key)
        XCTAssertEqual(store.storedPath(of: sub), "理财/基金")
        XCTAssertEqual(store.storedPath(of: sub, withNewName: "股票"), "理财/股票")
    }

    /// 内置父分类（交通）下的子分类路径
    func testBuiltInParentSubcategoryPath() throws {
        let trafficKey = ExpenditureCategory.traffic.rawValue
        guard let subway = store.subcategories(parentKey: trafficKey, kind: .expenditure).first(where: { $0.icon == "tram.fill" }) else {
            return XCTFail("未播种地铁子分类")
        }
        let path = trafficKey + CategoryStore.separator + subway.name
        XCTAssertTrue(CategoryResolver.isValid(path, kind: .expenditure))
        XCTAssertEqual(CategoryResolver.icon(for: path, kind: .expenditure), "tram.fill")
        XCTAssertEqual(CategoryResolver.parentRaw(path), trafficKey)
    }

    // MARK: - 改名与删除

    func testRenameCustomCategory() throws {
        let item = try store.add(kind: .expenditure, name: "咖啡", icon: "cup.and.saucer", colorHex: nil, parentKey: nil)
        try store.update(id: item.id, name: "咖啡奶茶", icon: "cup.and.saucer", colorHex: "#FF9919")
        let updated = store.item(id: item.id)
        XCTAssertEqual(updated?.name, "咖啡奶茶")
        XCTAssertEqual(updated?.colorHex, "#FF9919")
        XCTAssertFalse(CategoryResolver.isValid("咖啡", kind: .expenditure))
        XCTAssertTrue(CategoryResolver.isValid("咖啡奶茶", kind: .expenditure))
    }

    func testDeleteKeepsNothingButRemovesFromPicker() throws {
        let item = try store.add(kind: .expenditure, name: "订阅", icon: "repeat", colorHex: nil, parentKey: nil)
        store.delete(id: item.id)
        XCTAssertFalse(CategoryResolver.isValid("订阅", kind: .expenditure))
        // 历史账单里的名字仍能作为纯文本展示
        XCTAssertEqual(CategoryResolver.displayName(for: "订阅", kind: .expenditure), "订阅")
        XCTAssertEqual(CategoryResolver.icon(for: "订阅", kind: .expenditure), "tag")
    }

    func testDeletingParentRemovesItsSubcategories() throws {
        let parent = try store.add(kind: .expenditure, name: "露营", icon: "tent", colorHex: nil, parentKey: nil)
        _ = try store.add(kind: .expenditure, name: "营地费", icon: "tent", colorHex: nil, parentKey: parent.key)
        store.delete(id: parent.id)
        XCTAssertTrue(store.subcategories(parentKey: parent.key, kind: .expenditure).isEmpty)
    }

    // MARK: - 「+ 自定义」入口的图标占用（内含内置图标）

    func testTopLevelOptionsContainBuiltInAndCustom() throws {
        _ = try store.add(kind: .income, name: "报销", icon: "doc.text", colorHex: nil, parentKey: nil)
        let options = CategoryResolver.topLevelOptions(kind: .income)
        XCTAssertEqual(options.filter { !$0.isCustom }.count, IncomeCategory.allCases.count)
        XCTAssertTrue(options.contains { $0.raw == "报销" && $0.isCustom })
    }
}
