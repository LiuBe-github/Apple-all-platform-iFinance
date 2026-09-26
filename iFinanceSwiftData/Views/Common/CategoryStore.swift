//
//  CategoryStore.swift
//  iFinance
//
//  自定义分类 / 二级分类的本机存储（UserDefaults JSON，按账号隔离）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation
import SwiftUI
import Combine

// MARK: - 数据模型

/// 用户自定义分类（同时用于承载内置分类的二级分类）
struct CustomCategory: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: CategoryKind
    /// 父分类标识：内置分类用 rawValue（如「交通」），自定义分类用 UUID 字符串；nil = 一级分类
    var parentKey: String?
    /// 账单里实际存储的名字（子分类会拼成「父/子」）
    var name: String
    var icon: String
    /// 主题色（#RRGGBB）；nil = 自动配色
    var colorHex: String?
    /// 内置预设的本地化 key（如 cat.sub.bus）；用户改名后清空
    var builtInKey: String?
    var order: Int
    var createdAt: Date

    /// 一级分类标识
    var key: String { id.uuidString }
}

enum CategoryStoreError: LocalizedError {
    case emptyName
    case tooLongName
    case invalidCharacter
    case duplicateName
    case limitReached

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return L10n.string("category.custom.error.empty")
        case .tooLongName:
            return String(format: L10n.string("category.custom.error.too_long"), CategoryStore.maxNameLength)
        case .invalidCharacter:
            return L10n.string("category.custom.error.invalid")
        case .duplicateName:
            return L10n.string("category.custom.error.duplicate")
        case .limitReached:
            return L10n.string("category.custom.error.limit")
        }
    }
}

// MARK: - 存储

@MainActor
final class CategoryStore: ObservableObject {

    static let shared = CategoryStore()

    static let maxNameLength = 8
    static let maxCustomPerKind = 20
    static let maxSubPerParent = 20
    static let separator = "/"

    /// 交通的内置二级分类预设（内置换 icon 与本地化 key）
    static let trafficSubcategoryPresets: [(key: String, icon: String)] = [
        ("cat.sub.bus", "bus"),
        ("cat.sub.metro", "tram.fill"),
        ("cat.sub.bike", "bicycle"),
        ("cat.sub.plane", "airplane"),
        ("cat.sub.train", "train.side.front.car"),
        ("cat.sub.lightrail", "lightrail"),
        ("cat.sub.cityrail", "tram.circle")
    ]

    @Published private(set) var items: [CustomCategory] = []

    private let defaults: UserDefaults
    private var loadedAccountKey: String?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Key

    private var accountKey: String { AuthManager.shared.userIdentifier }

    private var storageKey: String { "custom_categories_v1_\(accountKey)" }

    private var seedKey: String { "custom_categories_seeded_v1_\(accountKey)" }

    // MARK: - 读取

    /// 重新载入（账号切换或进入相关页面时调用；账号未变且已有数据时直接返回）
    /// - Parameter force: 强制从 UserDefaults 重新读取（测试与账号切换场景）
    func reload(force: Bool = false) {
        if !force, loadedAccountKey == accountKey, !items.isEmpty { return }
        loadedAccountKey = accountKey
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CustomCategory].self, from: data) {
            items = decoded
        } else {
            items = []
        }
        seedIfNeeded()
    }

    /// 首次使用播种「交通」的内置二级分类
    private func seedIfNeeded() {
        guard !defaults.bool(forKey: seedKey) else { return }
        defaults.set(true, forKey: seedKey)
        let parentKey = ExpenditureCategory.traffic.rawValue
        for (index, preset) in Self.trafficSubcategoryPresets.enumerated() {
            items.append(
                CustomCategory(
                    id: UUID(),
                    kind: .expenditure,
                    parentKey: parentKey,
                    name: L10n.string(preset.key),
                    icon: preset.icon,
                    colorHex: nil,
                    builtInKey: preset.key,
                    order: index,
                    createdAt: Date()
                )
            )
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: - 查询

    /// 一级自定义分类
    func topLevel(_ kind: CategoryKind) -> [CustomCategory] {
        items
            .filter { $0.kind == kind && $0.parentKey == nil }
            .sorted { $0.order < $1.order }
    }

    /// 指定父分类下的二级分类
    func subcategories(parentKey: String, kind: CategoryKind) -> [CustomCategory] {
        items
            .filter { $0.kind == kind && $0.parentKey == parentKey }
            .sorted { $0.order < $1.order }
    }

    func item(id: UUID) -> CustomCategory? {
        items.first { $0.id == id }
    }

    func item(idString: String) -> CustomCategory? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return item(id: uuid)
    }

    /// 按「存储名 + 父级」查找
    func item(named name: String, parentKey: String?, kind: CategoryKind) -> CustomCategory? {
        items.first { $0.kind == kind && $0.parentKey == parentKey && $0.name == name }
    }

    /// 某个分类已占用的图标（一级看整个类型；二级看同一父级下）
    func takenIcons(kind: CategoryKind, parentKey: String?) -> Set<String> {
        if let parentKey {
            return Set(items.filter { $0.kind == kind && $0.parentKey == parentKey }.map(\.icon))
        }
        let builtInIcons = kind == .expenditure
            ? ExpenditureCategory.allCases.map(\.icon)
            : IncomeCategory.allCases.map(\.icon)
        return Set(builtInIcons).union(items.filter { $0.kind == kind && $0.parentKey == nil }.map(\.icon))
    }

    // MARK: - 编辑

    @discardableResult
    func add(
        kind: CategoryKind,
        name: String,
        icon: String,
        colorHex: String?,
        parentKey: String?
    ) throws -> CustomCategory {
        let trimmed = try validatedName(name, kind: kind, parentKey: parentKey, excluding: nil)
        let order = (items.filter { $0.kind == kind && $0.parentKey == parentKey }.map(\.order).max() ?? -1) + 1
        let item = CustomCategory(
            id: UUID(),
            kind: kind,
            parentKey: parentKey,
            name: trimmed,
            icon: icon,
            colorHex: colorHex,
            builtInKey: nil,
            order: order,
            createdAt: Date()
        )
        items.append(item)
        persist()
        return item
    }

    /// 修改名称 / 图标 / 颜色（名称变化时由调用方负责同步历史账单）
    func update(id: UUID, name: String, icon: String, colorHex: String?) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items[index]
        let trimmed = try validatedName(name, kind: item.kind, parentKey: item.parentKey, excluding: id)
        let renamed = trimmed != item.name
        items[index].name = trimmed
        items[index].icon = icon
        items[index].colorHex = colorHex
        // 用户改名后不再跟随内置文案
        if renamed { items[index].builtInKey = nil }
        persist()
    }

    /// 删除分类（连同其二级分类；历史账单由调用方决定是否保留）
    func delete(id: UUID) {
        guard let item = item(id: id) else { return }
        items.removeAll { $0.id == id || $0.parentKey == item.key }
        persist()
    }

    /// 改名前的旧存储路径（用于批量更新历史账单）
    func storedPath(of item: CustomCategory) -> String {
        guard let parentKey = item.parentKey else { return item.name }
        let parentName = builtInName(forKey: parentKey, kind: item.kind)
            ?? self.item(idString: parentKey)?.name
            ?? parentKey
        return parentName + Self.separator + item.name
    }

    /// 改名后的新存储路径
    func storedPath(of item: CustomCategory, withNewName newName: String) -> String {
        guard let parentKey = item.parentKey else { return newName }
        let parentName = builtInName(forKey: parentKey, kind: item.kind)
            ?? self.item(idString: parentKey)?.name
            ?? parentKey
        return parentName + Self.separator + newName
    }

    /// 内置分类的 rawValue（key 就是 rawValue 时返回自身）
    func builtInName(forKey key: String, kind: CategoryKind) -> String? {
        switch kind {
        case .expenditure:
            return ExpenditureCategory(rawValue: key)?.rawValue
        case .income:
            return IncomeCategory(rawValue: key)?.rawValue
        }
    }

    // MARK: - 校验

    private func validatedName(
        _ name: String,
        kind: CategoryKind,
        parentKey: String?,
        excluding id: UUID?
    ) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryStoreError.emptyName }
        guard trimmed.count <= Self.maxNameLength else { throw CategoryStoreError.tooLongName }
        guard !trimmed.contains(Self.separator) else { throw CategoryStoreError.invalidCharacter }

        // 一级分类不得与内置分类重名
        if parentKey == nil {
            let builtInNames = kind == .expenditure
                ? ExpenditureCategory.allCases.map(\.rawValue)
                : IncomeCategory.allCases.map(\.rawValue)
            if builtInNames.contains(trimmed) { throw CategoryStoreError.duplicateName }
        }

        let duplicated = items.contains {
            $0.kind == kind && $0.parentKey == parentKey && $0.name == trimmed && $0.id != id
        }
        if duplicated { throw CategoryStoreError.duplicateName }

        if id == nil {
            let count = items.filter { $0.kind == kind && $0.parentKey == parentKey }.count
            let limit = parentKey == nil ? Self.maxCustomPerKind : Self.maxSubPerParent
            if count >= limit { throw CategoryStoreError.limitReached }
        }
        return trimmed
    }
}
