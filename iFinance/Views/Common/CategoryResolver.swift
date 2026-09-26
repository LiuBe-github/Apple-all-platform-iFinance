//
//  CategoryResolver.swift
//  iFinance
//
//  分类解析层：把账单里存的字符串（内置分类 rawValue / 自定义分类名 / 「父/子」复合路径）
//  统一解析成展示名、图标与配色。全 App 不再直接用 ExpenditureCategory(rawValue:) 反查。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation
import SwiftUI

/// 选择器里的一项分类
struct CategoryOption: Identifiable, Hashable {
    let raw: String
    let title: String
    let icon: String
    let color: Color
    let isCustom: Bool

    var id: String { raw }
}

@MainActor
enum CategoryResolver {

    // MARK: - 路径

    /// 拆分「父/子」复合路径
    static func split(_ raw: String) -> (parent: String, child: String?) {
        guard let index = raw.firstIndex(of: Character(CategoryStore.separator)) else {
            return (raw, nil)
        }
        let parent = String(raw[raw.startIndex..<index])
        let child = String(raw[raw.index(after: index)...])
        return (parent, child.isEmpty ? nil : child)
    }

    /// 一级分类名（用于统计聚合：交通/地铁 → 交通）
    static func parentRaw(_ raw: String) -> String {
        split(raw).parent
    }

    /// 内置分类判定
    static func isBuiltIn(_ name: String, kind: CategoryKind) -> Bool {
        switch kind {
        case .expenditure: return ExpenditureCategory(rawValue: name) != nil
        case .income: return IncomeCategory(rawValue: name) != nil
        }
    }

    /// 由「账单里存储的父分类名」求父级 key（内置分类 = rawValue 本身；自定义分类 = UUID 字符串）
    static func parentKey(forStoredParent name: String, kind: CategoryKind) -> String? {
        if isBuiltIn(name, kind: kind) { return name }
        return CategoryStore.shared.item(named: name, parentKey: nil, kind: kind)?.key
    }

    // MARK: - 展示

    static func displayName(for raw: String, kind: CategoryKind) -> String {
        let (parent, child) = split(raw)
        let parentName = singleName(parent, kind: kind, parentKey: nil)
        guard let child else { return parentName }
        let key = parentKey(forStoredParent: parent, kind: kind)
        return parentName + " · " + singleName(child, kind: kind, parentKey: key)
    }

    static func icon(for raw: String, kind: CategoryKind) -> String {
        let (parent, child) = split(raw)
        if let child,
           let item = categoryItem(named: child, parentName: parent, kind: kind) {
            return item.icon
        }
        if child == nil,
           let item = CategoryStore.shared.item(named: parent, parentKey: nil, kind: kind) {
            return item.icon
        }
        switch kind {
        case .expenditure: return ExpenditureCategory(rawValue: parent)?.icon ?? "tag"
        case .income: return IncomeCategory(rawValue: parent)?.icon ?? "tag"
        }
    }

    static func color(for raw: String, kind: CategoryKind) -> Color {
        let (parent, child) = split(raw)
        if let child,
           let item = categoryItem(named: child, parentName: parent, kind: kind) {
            if let hex = item.colorHex, let color = CategoryPalette.color(hex: hex) { return color }
            return CategoryPalette.autoColor(seed: item.name, kind: kind)
        }
        if child == nil,
           let item = CategoryStore.shared.item(named: parent, parentKey: nil, kind: kind) {
            if let hex = item.colorHex, let color = CategoryPalette.color(hex: hex) { return color }
            return CategoryPalette.autoColor(seed: item.name, kind: kind)
        }
        switch kind {
        case .expenditure:
            if let builtIn = ExpenditureCategory(rawValue: parent) { return CategoryPalette.color(for: builtIn) }
        case .income:
            if let builtIn = IncomeCategory(rawValue: parent) { return CategoryPalette.color(for: builtIn) }
        }
        return CategoryPalette.unknown
    }

    /// 内置分类的本地化名（非内置返回 nil）
    static func builtInDisplayName(_ raw: String, kind: CategoryKind) -> String? {
        switch kind {
        case .expenditure: return ExpenditureCategory(rawValue: raw)?.localizedDisplayName
        case .income: return IncomeCategory(rawValue: raw)?.localizedDisplayName
        }
    }

    // MARK: - 校验

    /// 账单分类是否合法（内置或自定义；带子路径时子分类必须存在）
    static func isValid(_ raw: String, kind: CategoryKind) -> Bool {
        let (parent, child) = split(raw)
        guard !parent.isEmpty else { return false }
        if let child {
            return categoryItem(named: child, parentName: parent, kind: kind) != nil
        }
        return isBuiltIn(parent, kind: kind)
            || CategoryStore.shared.item(named: parent, parentKey: nil, kind: kind) != nil
    }

    // MARK: - 选择器数据

    /// 一级分类选项（内置在前、自定义在后）
    static func topLevelOptions(kind: CategoryKind) -> [CategoryOption] {
        var options: [CategoryOption] = []
        switch kind {
        case .expenditure:
            options = ExpenditureCategory.allCases.map {
                CategoryOption(
                    raw: $0.rawValue,
                    title: $0.localizedDisplayName,
                    icon: $0.icon,
                    color: CategoryPalette.color(for: $0),
                    isCustom: false
                )
            }
        case .income:
            options = IncomeCategory.allCases.map {
                CategoryOption(
                    raw: $0.rawValue,
                    title: $0.localizedDisplayName,
                    icon: $0.icon,
                    color: CategoryPalette.color(for: $0),
                    isCustom: false
                )
            }
        }
        let custom = CategoryStore.shared.topLevel(kind).map { item in
            CategoryOption(
                raw: item.name,
                title: displayName(for: item.name, kind: kind),
                icon: item.icon,
                color: color(for: item.name, kind: kind),
                isCustom: true
            )
        }
        return options + custom
    }

    /// 指定父分类下的二级分类（父分类用「存储名」传入）
    static func subOptions(forParent parentRaw: String, kind: CategoryKind) -> [CategoryOption] {
        guard let key = parentKey(forStoredParent: parentRaw, kind: kind) else { return [] }
        return CategoryStore.shared.subcategories(parentKey: key, kind: kind).map { item in
            let raw = parentRaw + CategoryStore.separator + item.name
            return CategoryOption(
                raw: raw,
                title: displayName(for: raw, kind: kind),
                icon: item.icon,
                color: color(for: raw, kind: kind),
                isCustom: true
            )
        }
    }

    // MARK: - 私有

    private static func singleName(_ name: String, kind: CategoryKind, parentKey: String?) -> String {
        if let builtIn = builtInDisplayName(name, kind: kind) { return builtIn }
        if let item = CategoryStore.shared.item(named: name, parentKey: parentKey, kind: kind) {
            if let key = item.builtInKey { return L10n.string(key) }
            return item.name
        }
        return name
    }

    private static func categoryItem(named name: String, parentName: String, kind: CategoryKind) -> CustomCategory? {
        guard let key = parentKey(forStoredParent: parentName, kind: kind) else { return nil }
        return CategoryStore.shared.item(named: name, parentKey: key, kind: kind)
    }
}
