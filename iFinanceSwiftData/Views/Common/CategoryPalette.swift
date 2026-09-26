//
//  CategoryPalette.swift
//  iFinance
//
//  分类配色与分类种类（预算页、趋势页饼图共用）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

enum CategoryPalette {
    /// 8 色循环调色板（浅色模式；按分类在枚举中的顺序取色）
    /// R16：色相沿用原调色板，明度已收进同一感知带，深浅两套。
    static var colors: [Color] { seriesColors(for: .light) }

    static func seriesColors(for scheme: ColorScheme) -> [Color] {
        (scheme == .dark ? ChartSeriesStyle.seriesDark : ChartSeriesStyle.seriesLight).map(\.color)
    }

    /// 无法解析的分类（历史脏数据）用中性灰
    static var unknown: Color { ChartSeriesStyle.unknown(for: .light) }

    static func unknown(for scheme: ColorScheme) -> Color {
        ChartSeriesStyle.unknown(for: scheme)
    }

    /// 分类身份色：支出红、收入绿（R17：本 App 为记账惯例，与国内「红涨绿跌」相反）
    static func accent(for kind: CategoryKind, scheme: ColorScheme = .light) -> Color {
        ChartSeriesStyle.accent(for: kind, scheme: scheme)
    }

    static func color(index: Int, scheme: ColorScheme = .light) -> Color {
        let palette = seriesColors(for: scheme)
        let count = palette.count
        return palette[((index % count) + count) % count]
    }

    static func color(for category: ExpenditureCategory, scheme: ColorScheme = .light) -> Color {
        color(index: ExpenditureCategory.allCases.firstIndex(of: category) ?? 0, scheme: scheme)
    }

    static func color(for category: IncomeCategory, scheme: ColorScheme = .light) -> Color {
        color(index: IncomeCategory.allCases.firstIndex(of: category) ?? 0, scheme: scheme)
    }

    /// 稳定自动配色（同名分类永远得到同一颜色）
    static func autoColor(seed: String, kind: CategoryKind, scheme: ColorScheme = .light) -> Color {
        let offset = kind == .expenditure ? 0 : 3
        let hash = seed.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0xFFFF
        }
        return color(index: hash + offset, scheme: scheme)
    }

    /// 数据可视化专用取色（饼图扇区 + 预算页分类明细列表）：内置按枚举顺序取 8 色板，自定义按名称稳定取色。
    /// 分类身份色（网格 / 账单行 / 管理页）请用 `CategoryKind.accentColor`。
    static func chartColor(for rawValue: String, kind: CategoryKind, scheme: ColorScheme = .light) -> Color {
        let parent = rawValue.split(separator: "/").first.map(String.init) ?? rawValue
        switch kind {
        case .expenditure:
            if let builtIn = ExpenditureCategory(rawValue: parent),
               let index = ExpenditureCategory.allCases.firstIndex(of: builtIn) {
                return color(index: index, scheme: scheme)
            }
        case .income:
            if let builtIn = IncomeCategory(rawValue: parent),
               let index = IncomeCategory.allCases.firstIndex(of: builtIn) {
                return color(index: index, scheme: scheme)
            }
        }
        return autoColor(seed: parent, kind: kind, scheme: scheme)
    }
}

/// 饼图使用的分类种类：决定分类展示名与配色
enum CategoryKind: String, Codable, CaseIterable {
    case expenditure
    case income

    /// 分类身份色（浅色模式；显式传 scheme 请用 `accentColor(for:)`）
    var accentColor: Color {
        ChartSeriesStyle.accent(for: self, scheme: .light)
    }

    /// 分类身份色（随深浅模式）
    func accentColor(for scheme: ColorScheme) -> Color {
        ChartSeriesStyle.accent(for: self, scheme: scheme)
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
    func color(for rawValue: String, scheme: ColorScheme = .light) -> Color {
        CategoryPalette.chartColor(for: rawValue, kind: self, scheme: scheme)
    }
}
