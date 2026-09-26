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

    /// 视图观察用：只在增删改或视图生命周期 `reload()` 时发布
    @Published private(set) var items: [CustomCategory] = []

    /// 读取用缓存：解析层（账单行 / 图表 / 选择器）随时读取，必要时同步从磁盘载入，渲染期不会发布变更
    private var loadedItems: [CustomCategory] = []
    private var loadedAccountKey: String?
    private var isLoaded = false

    /// 数据版本号：每次载入/写入 +1，供解析层做缓存失效
    private(set) var revision: Int = 0

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Key

    private var accountKey: String { AuthManager.shared.userIdentifier }

    private var storageKey: String { "custom_categories_v1_\(accountKey)" }

    private var seedKey: String { "custom_categories_seeded_v1_\(accountKey)" }

    // MARK: - 读取

    /// 读取入口（解析层用）：需要时同步从磁盘载入，**不发布变更**，可在视图渲染过程中安全调用。
    /// 这是修复「重启后二级分类显示问号」的关键：账单列表不再依赖别的页面先把数据读进内存。
    var currentItems: [CustomCategory] {
        ensureLoaded()
        return loadedItems
    }

    /// 重新载入（账号切换或进入相关页面时调用）并补一次发布，驱动观察 `items` 的视图刷新
    /// - Parameter force: 强制从 UserDefaults 重新读取（测试场景）
    func reload(force: Bool = false) {
        ensureLoaded(force: force)
        if items != loadedItems { items = loadedItems }
    }

    /// 仅测试：清空内存缓存以模拟「App 重启」（不动磁盘数据）
    func resetInMemoryCacheForTesting() {
        loadedItems = []
        items = []
        loadedAccountKey = nil
        isLoaded = false
    }

    /// 确保内存缓存与当前账号一致（账号切换会自动重新载入）
    private func ensureLoaded(force: Bool = false) {
        let key = accountKey
        guard force || !isLoaded || loadedAccountKey != key else { return }
        loadedAccountKey = key
        isLoaded = true
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CustomCategory].self, from: data) {
            loadedItems = decoded
        } else {
            loadedItems = []
        }
        revision &+= 1
        seedIfNeeded()
    }

    /// 首次使用播种「交通」的内置二级分类（只落盘、不发布，可在渲染期调用）
    private func seedIfNeeded() {
        guard !defaults.bool(forKey: seedKey) else { return }
        defaults.set(true, forKey: seedKey)
        let parentKey = ExpenditureCategory.traffic.rawValue
        for (index, preset) in Self.trafficSubcategoryPresets.enumerated() {
            loadedItems.append(
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
        writeToDisk()
    }

    /// 写入磁盘（不发布）
    private func writeToDisk() {
        guard let data = try? JSONEncoder().encode(loadedItems) else { return }
        defaults.set(data, forKey: storageKey)
        revision &+= 1
    }

    /// 写入磁盘并发布（增删改后调用）
    private func persist() {
        writeToDisk()
        items = loadedItems
    }

    // MARK: - 查询

    /// 一级自定义分类
    func topLevel(_ kind: CategoryKind) -> [CustomCategory] {
        currentItems
            .filter { $0.kind == kind && $0.parentKey == nil }
            .sorted { $0.order < $1.order }
    }

    /// 指定父分类下的二级分类
    func subcategories(parentKey: String, kind: CategoryKind) -> [CustomCategory] {
        currentItems
            .filter { $0.kind == kind && $0.parentKey == parentKey }
            .sorted { $0.order < $1.order }
    }

    func item(id: UUID) -> CustomCategory? {
        currentItems.first { $0.id == id }
    }

    func item(idString: String) -> CustomCategory? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return item(id: uuid)
    }

    /// 按「存储名 + 父级」查找
    func item(named name: String, parentKey: String?, kind: CategoryKind) -> CustomCategory? {
        currentItems.first { $0.kind == kind && $0.parentKey == parentKey && $0.name == name }
    }

    /// 某个分类已占用的图标（一级看整个类型；二级看同一父级下）
    func takenIcons(kind: CategoryKind, parentKey: String?) -> Set<String> {
        let all = currentItems
        if let parentKey {
            return Set(all.filter { $0.kind == kind && $0.parentKey == parentKey }.map(\.icon))
        }
        let builtInIcons = kind == .expenditure
            ? ExpenditureCategory.allCases.map(\.icon)
            : IncomeCategory.allCases.map(\.icon)
        return Set(builtInIcons).union(all.filter { $0.kind == kind && $0.parentKey == nil }.map(\.icon))
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
        let order = (currentItems.filter { $0.kind == kind && $0.parentKey == parentKey }.map(\.order).max() ?? -1) + 1
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
        loadedItems.append(item)
        persist()
        return item
    }

    /// 修改名称 / 图标 / 颜色（名称变化时由调用方负责同步历史账单）
    func update(id: UUID, name: String, icon: String, colorHex: String?) throws {
        guard let index = currentItems.firstIndex(where: { $0.id == id }) else { return }
        let item = loadedItems[index]
        let trimmed = try validatedName(name, kind: item.kind, parentKey: item.parentKey, excluding: id)
        let renamed = trimmed != item.name
        loadedItems[index].name = trimmed
        loadedItems[index].icon = icon
        loadedItems[index].colorHex = colorHex
        // 用户改名后不再跟随内置文案
        if renamed { loadedItems[index].builtInKey = nil }
        persist()
    }

    /// 删除分类（连同其二级分类；历史账单由调用方决定是否保留）
    func delete(id: UUID) {
        guard let item = item(id: id) else { return }
        loadedItems.removeAll { $0.id == id || $0.parentKey == item.key }
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

        let all = currentItems
        let duplicated = all.contains {
            $0.kind == kind && $0.parentKey == parentKey && $0.name == trimmed && $0.id != id
        }
        if duplicated { throw CategoryStoreError.duplicateName }

        if id == nil {
            let count = all.filter { $0.kind == kind && $0.parentKey == parentKey }.count
            let limit = parentKey == nil ? Self.maxCustomPerKind : Self.maxSubPerParent
            if count >= limit { throw CategoryStoreError.limitReached }
        }
        return trimmed
    }
}
