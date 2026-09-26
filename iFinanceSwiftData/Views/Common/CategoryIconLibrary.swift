//
//  CategoryIconLibrary.swift
//  iFinance
//
//  自定义分类的精选 SF Symbols 图标库（按主题分组，供图标选择器使用）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation

struct CategoryIconGroup: Identifiable {
    let titleKey: String
    let icons: [String]

    var id: String { titleKey }
}

enum CategoryIconLibrary {

    /// 精选图标（全部核对过系统符号库存在性）
    static let groups: [CategoryIconGroup] = [
        CategoryIconGroup(titleKey: "category.icon.group.food", icons: [
            "fork.knife", "cup.and.saucer", "mug", "takeoutbag.and.cup.and.straw",
            "birthday.cake", "carrot", "popcorn", "wineglass", "fish"
        ]),
        CategoryIconGroup(titleKey: "category.icon.group.travel", icons: [
            "bus", "tram.fill", "tram.circle", "bicycle", "airplane", "airplane.departure",
            "car", "car.side", "fuelpump", "road.lanes", "ferry", "lightrail",
            "train.side.front.car", "scooter", "parkingsign", "cablecar"
        ]),
        CategoryIconGroup(titleKey: "category.icon.group.shopping", icons: [
            "cart", "bag", "basket", "gift", "creditcard", "tag", "shippingbox", "scissors"
        ]),
        CategoryIconGroup(titleKey: "category.icon.group.home", icons: [
            "house", "sofa", "bed.double", "washer", "shower", "refrigerator",
            "microwave", "oven", "toilet", "chair.lounge", "lamp.desk", "trash"
        ]),
        CategoryIconGroup(titleKey: "category.icon.group.digital", icons: [
            "laptopcomputer", "desktopcomputer", "iphone", "display", "keyboard",
            "computermouse", "headphones", "camera", "tv", "gamecontroller",
            "memorychip", "cpu", "externaldrive", "printer"
        ]),
        CategoryIconGroup(titleKey: "category.icon.group.health", icons: [
            "cross.case", "pills", "staroflife", "bandage", "facemask",
            "stethoscope", "heart.text.square", "syringe"
        ]),
        CategoryIconGroup(titleKey: "category.icon.group.work", icons: [
            "briefcase", "book", "graduationcap", "pencil.and.ruler",
            "hammer", "wrench.and.screwdriver", "building.2", "building.columns"
        ]),
        CategoryIconGroup(titleKey: "category.icon.group.finance", icons: [
            "banknote", "dollarsign.circle", "dollarsign.square", "wallet.bifold",
            "chart.line.uptrend.xyaxis", "percent", "key.fill", "hand.raised"
        ]),
        CategoryIconGroup(titleKey: "category.icon.group.life", icons: [
            "figure.run", "dumbbell", "tent", "backpack", "suitcase", "beach.umbrella",
            "ticket", "film", "music.note", "sparkles", "star", "heart",
            "leaf", "pawprint", "bird", "tortoise", "smoke", "globe",
            "sun.max", "moon.stars", "dice", "party.popper"
        ])
    ]

    /// 全部图标（去重后）
    static var allIcons: [String] {
        var seen: Set<String> = []
        return groups.flatMap(\.icons).filter { seen.insert($0).inserted }
    }

    /// 关键字过滤（空关键字返回全部分组）
    static func filtered(keyword: String) -> [CategoryIconGroup] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return groups }
        return groups.compactMap { group in
            let matched = group.icons.filter { $0.lowercased().contains(trimmed) }
            return matched.isEmpty ? nil : CategoryIconGroup(titleKey: group.titleKey, icons: matched)
        }
    }
}
