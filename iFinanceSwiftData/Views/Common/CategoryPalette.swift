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
}

/// 饼图使用的分类种类：决定分类展示名与配色
enum CategoryKind {
    case expenditure
    case income

    func displayName(for rawValue: String) -> String {
        switch self {
        case .expenditure:
            return ExpenditureCategory(rawValue: rawValue)?.localizedDisplayName ?? rawValue
        case .income:
            return IncomeCategory(rawValue: rawValue)?.localizedDisplayName ?? rawValue
        }
    }

    func color(for rawValue: String) -> Color {
        switch self {
        case .expenditure:
            guard let category = ExpenditureCategory(rawValue: rawValue) else { return CategoryPalette.unknown }
            return CategoryPalette.color(for: category)
        case .income:
            guard let category = IncomeCategory(rawValue: rawValue) else { return CategoryPalette.unknown }
            return CategoryPalette.color(for: category)
        }
    }
}

