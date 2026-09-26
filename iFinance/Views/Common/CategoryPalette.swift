//
//  CategoryPalette.swift
//  iFinance
//
//  分类配色与分类种类（预算页、趋势页饼图共用）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

enum CategoryPalette {
    /// 8 色循环调色板（按分类在枚举中的顺序取色）
    static let colors: [Color] = [
        Color(red: 0.18, green: 0.60, blue: 1.0),
        Color(red: 0.30, green: 0.78, blue: 0.44),
        Color(red: 1.0,  green: 0.60, blue: 0.10),
        Color(red: 0.75, green: 0.35, blue: 1.0),
        Color(red: 1.0,  green: 0.30, blue: 0.30),
        Color(red: 0.10, green: 0.75, blue: 0.85),
        Color(red: 1.0,  green: 0.80, blue: 0.10),
        Color(red: 0.55, green: 0.55, blue: 0.60)
    ]

    /// 无法解析的分类（历史脏数据）用中性灰
    static let unknown = Color(red: 0.55, green: 0.55, blue: 0.60)

    /// 自定义分类可选的主题色（十六进制，供图标/饼图使用）
    static let customColors: [String] = [
        "#2E9BFF", "#4DC770", "#FF9919", "#BF59FF", "#FF4D4D", "#1AC0D9",
        "#FFCC19", "#8C8C99", "#F26A9B", "#5C7CFA", "#20C997", "#B07CFF"
    ]

    static func color(index: Int) -> Color {
        let count = colors.count
        return colors[((index % count) + count) % count]
    }

    static func color(for category: ExpenditureCategory) -> Color {
        color(index: ExpenditureCategory.allCases.firstIndex(of: category) ?? 0)
    }

    static func color(for category: IncomeCategory) -> Color {
        color(index: IncomeCategory.allCases.firstIndex(of: category) ?? 0)
    }

    /// 十六进制颜色（#RRGGBB）
    static func color(hex: String) -> Color? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let raw = UInt64(value, radix: 16) else { return nil }
        let red = Double((raw >> 16) & 0xFF) / 255
        let green = Double((raw >> 8) & 0xFF) / 255
        let blue = Double(raw & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }

    /// 未指定主题色时的稳定自动配色（同名分类永远得到同一颜色）
    static func autoColor(seed: String, kind: CategoryKind) -> Color {
        let offset = kind == .expenditure ? 0 : 3
        let hash = seed.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0xFFFF
        }
        return color(index: hash + offset)
    }
}

/// 饼图使用的分类种类：决定分类展示名与配色
enum CategoryKind: String, Codable, CaseIterable {
    case expenditure
    case income

    /// 账单里的类型字符串
    var billType: String {
        switch self {
        case .expenditure: return "expenditure"
        case .income: return "income"
        }
    }

    init?(billType: String) {
        switch billType {
        case "expenditure": self = .expenditure
        case "income": self = .income
        default: return nil
        }
    }

    @MainActor
    func displayName(for rawValue: String) -> String {
        CategoryResolver.displayName(for: rawValue, kind: self)
    }

    @MainActor
    func color(for rawValue: String) -> Color {
        CategoryResolver.color(for: rawValue, kind: self)
    }
}
