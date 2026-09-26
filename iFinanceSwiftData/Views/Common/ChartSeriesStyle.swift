//
//  ChartSeriesStyle.swift
//  iFinance
//
//  图表系列语义色与「不以颜色为唯一区分手段」的形状通道。
//  - R16：**保留改版前的原始配色**（用户明确要求「我要原来的颜色」，不接受明度均衡后的变暗观感）；
//         因此浅色 / 深色使用同一组原色，对比度目标（≥3:1）不再是本项目的验收项，
//         改由「形状 / 符号 + 文字图例」保证可辨识（R14）。
//  - R17：本 App 为「红＝支出、绿＝收入」的记账惯例，与国内股票「红涨绿跌」相反，
//         因此图例必须带文字（收入 / 支出），不能只靠颜色。
//  - R14：系统「不以颜色为唯一区分手段」开启时，用形状 / 符号区分系列。
//
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

/// 可参与对比度计算的 RGB 颜色（0...1）
struct ChartRGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color { Color(red: red, green: green, blue: blue) }

    /// WCAG 相对亮度（用于对比度断言）
    var relativeLuminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 对比度
    func contrastRatio(against other: ChartRGB) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// 图例形状（R14：不依赖颜色时用形状区分）
enum ChartLegendShape: CaseIterable {
    case circle
    case square
    case triangle

    var shape: AnyShape {
        switch self {
        case .circle: return AnyShape(Circle())
        case .square: return AnyShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        case .triangle: return AnyShape(TriangleShape())
        }
    }

    static func shape(forIndex index: Int) -> ChartLegendShape {
        let all = ChartLegendShape.allCases
        return all[((index % all.count) + all.count) % all.count]
    }
}

/// 简单三角形（图例用）
struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

enum ChartSeriesStyle {

    /// 卡片背景参照色（用于对比度断言）：浅色 `#F2F2F7`、深色 `#1C1C1E`
    static let lightCardBackground = ChartRGB(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255)
    static let darkCardBackground = ChartRGB(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)

    // MARK: - 语义色

    /// 支出红（原值 `Color(red: 1.0, green: 0.27, blue: 0.23)`）
    static let expenseLight = ChartRGB(red: 1.0, green: 0.27, blue: 0.23)
    static let expenseDark = expenseLight
    /// 收入绿（原值 `Color(red: 0.18, green: 0.78, blue: 0.44)`）
    static let incomeLight = ChartRGB(red: 0.18, green: 0.78, blue: 0.44)
    static let incomeDark = incomeLight
    static let unknownLight = ChartRGB(red: 0.55, green: 0.55, blue: 0.60)
    static let unknownDark = unknownLight

    // MARK: - 8 色系列板（色相沿用原调色板，明度收进同一带）

    /// 改版前的 8 色循环调色板（原样保留；深浅模式共用）
    static let seriesLight: [ChartRGB] = [
        ChartRGB(red: 0.18, green: 0.60, blue: 1.0),   // 蓝
        ChartRGB(red: 0.30, green: 0.78, blue: 0.44),  // 绿
        ChartRGB(red: 1.0,  green: 0.60, blue: 0.10),  // 橙
        ChartRGB(red: 0.75, green: 0.35, blue: 1.0),   // 紫
        ChartRGB(red: 1.0,  green: 0.30, blue: 0.30),  // 红
        ChartRGB(red: 0.10, green: 0.75, blue: 0.85),  // 青
        ChartRGB(red: 1.0,  green: 0.80, blue: 0.10),  // 黄
        ChartRGB(red: 0.55, green: 0.55, blue: 0.60)   // 灰
    ]

    static let seriesDark = seriesLight

    // MARK: - 取色

    static func expense(for scheme: ColorScheme) -> Color {
        (scheme == .dark ? expenseDark : expenseLight).color
    }

    static func income(for scheme: ColorScheme) -> Color {
        (scheme == .dark ? incomeDark : incomeLight).color
    }

    static func unknown(for scheme: ColorScheme) -> Color {
        (scheme == .dark ? unknownDark : unknownLight).color
    }

    static func series(index: Int, scheme: ColorScheme) -> Color {
        let palette = scheme == .dark ? seriesDark : seriesLight
        let count = palette.count
        return palette[((index % count) + count) % count].color
    }

    static func accent(for kind: CategoryKind, scheme: ColorScheme) -> Color {
        kind == .expenditure ? expense(for: scheme) : income(for: scheme)
    }

    // MARK: - 形状通道（R14）

    /// 收入 / 支出两个系列在「不以颜色区分」时使用的符号
    static func markerSymbolName(for kind: CategoryKind) -> String {
        kind == .expenditure ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill"
    }
}
