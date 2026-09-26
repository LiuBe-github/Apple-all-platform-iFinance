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

    /// 稳定自动配色（同名分类永远得到同一颜色）
    static func autoColor(seed: String, kind: CategoryKind) -> Color {
        let offset = kind == .expenditure ? 0 : 3
        let hash = seed.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0xFFFF
        }
        return color(index: hash + offset)
    }

    /// 数据可视化专用取色（饼图扇区 + 预算页分类明细列表）：内置按枚举顺序取 8 色板，自定义按名称稳定取色。
    /// 分类身份色（网格 / 账单行 / 管理页）请用 `CategoryKind.accentColor`。
    static func chartColor(for rawValue: String, kind: CategoryKind) -> Color {
        let parent = rawValue.split(separator: "/").first.map(String.init) ?? rawValue
        switch kind {
        case .expenditure:
            if let builtIn = ExpenditureCategory(rawValue: parent),
               let index = ExpenditureCategory.allCases.firstIndex(of: builtIn) {
                return color(index: index)
            }
        case .income:
            if let builtIn = IncomeCategory(rawValue: parent),
               let index = IncomeCategory.allCases.firstIndex(of: builtIn) {
                return color(index: index)
            }
        }
        return autoColor(seed: parent, kind: kind)
    }
}

/// 饼图使用的分类种类：决定分类展示名与配色
enum CategoryKind: String, Codable, CaseIterable {
    case expenditure
    case income

    /// 分类身份色：支出统一红、收入统一绿（含自定义分类与二级分类）
    var accentColor: Color {
        switch self {
        case .expenditure: return Color(red: 1.0, green: 0.27, blue: 0.23)
        case .income: return Color(red: 0.18, green: 0.78, blue: 0.44)
        }
    }

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

    /// 数据可视化色（饼图与同页明细共用；分类身份色见 `accentColor`）
    func color(for rawValue: String) -> Color {
        CategoryPalette.chartColor(for: rawValue, kind: self)
    }
}
