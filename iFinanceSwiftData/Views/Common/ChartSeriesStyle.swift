//
//  ChartSeriesStyle.swift
//  iFinance
//
//  图表系列语义色与「不以颜色为唯一区分手段」的形状通道。
//  - R16：8 色系列的相对亮度收在同一感知带（浅色 L≈0.20、深色 L≈0.44），
//         对卡片背景对比度浅色 ≥3.7:1、深色 ≥7.9:1；色相沿用原有 8 色血统。
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

    static let expenseLight = ChartRGB(red: 0xD6 / 255, green: 0x3D / 255, blue: 0x3D / 255)
    static let expenseDark = ChartRGB(red: 0xF5 / 255, green: 0x8B / 255, blue: 0x8B / 255)
    static let incomeLight = ChartRGB(red: 0x19 / 255, green: 0x8E / 255, blue: 0x44 / 255)
    static let incomeDark = ChartRGB(red: 0x28 / 255, green: 0xC6 / 255, blue: 0x62 / 255)
    static let unknownLight = ChartRGB(red: 0x7B / 255, green: 0x81 / 255, blue: 0x8E / 255)
    static let unknownDark = ChartRGB(red: 0xA9 / 255, green: 0xAD / 255, blue: 0xB6 / 255)

    // MARK: - 8 色系列板（色相沿用原调色板，明度收进同一带）

    static let seriesLight: [ChartRGB] = [
        ChartRGB(red: 0x37 / 255, green: 0x79 / 255, blue: 0xE4 / 255), // 蓝
        ChartRGB(red: 0x19 / 255, green: 0x8E / 255, blue: 0x44 / 255), // 绿
        ChartRGB(red: 0xAB / 255, green: 0x6E / 255, blue: 0x08 / 255), // 橙
        ChartRGB(red: 0xA3 / 255, green: 0x52 / 255, blue: 0xEF / 255), // 紫
        ChartRGB(red: 0xE0 / 255, green: 0x40 / 255, blue: 0x40 / 255), // 红
        ChartRGB(red: 0x04 / 255, green: 0x87 / 255, blue: 0x9E / 255), // 青
        ChartRGB(red: 0x9B / 255, green: 0x76 / 255, blue: 0x05 / 255), // 黄褐
        ChartRGB(red: 0x75 / 255, green: 0x7B / 255, blue: 0x89 / 255)  // 灰
    ]

    static let seriesDark: [ChartRGB] = [
        ChartRGB(red: 0x87 / 255, green: 0xB2 / 255, blue: 0xF9 / 255),
        ChartRGB(red: 0x33 / 255, green: 0xCA / 255, blue: 0x6A / 255),
        ChartRGB(red: 0xF5 / 255, green: 0x9F / 255, blue: 0x0C / 255),
        ChartRGB(red: 0xCD / 255, green: 0x9D / 255, blue: 0xFA / 255),
        ChartRGB(red: 0xF6 / 255, green: 0x97 / 255, blue: 0x97 / 255),
        ChartRGB(red: 0x2D / 255, green: 0xC2 / 255, blue: 0xDB / 255),
        ChartRGB(red: 0xDE / 255, green: 0xAA / 255, blue: 0x08 / 255),
        ChartRGB(red: 0xAE / 255, green: 0xB1 / 255, blue: 0xB9 / 255)
    ]

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
