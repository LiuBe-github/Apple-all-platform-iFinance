//
//  HeatmapRamp.swift
//  iFinance
//
//  热力图 5 级色阶（0 = 无记录 + 1…4 级）。
//  - R16：等级亮度单调（浅色模式越深、深色模式越亮），最高级对卡片背景对比度 ≥3:1
//  - R15：等级之间还有格子间距做视觉分隔
//  色阶以 RGB 元组定义，便于单测直接断言亮度与对比度。
//
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

enum HeatmapRamp {

    /// 浅色模式：等级越高越深
    static let light: [ChartRGB] = [
        ChartRGB(red: 0xE5 / 255, green: 0xE5 / 255, blue: 0xEA / 255), // 0 无记录
        ChartRGB(red: 0xD7 / 255, green: 0xE5 / 255, blue: 0xFD / 255), // 1
        ChartRGB(red: 0xA5 / 255, green: 0xC5 / 255, blue: 0xFB / 255), // 2
        ChartRGB(red: 0x6A / 255, green: 0xA0 / 255, blue: 0xF8 / 255), // 3
        ChartRGB(red: 0x35 / 255, green: 0x76 / 255, blue: 0xDE / 255)  // 4
    ]

    /// 深色模式：等级越高越亮（原先直接复用浅色色阶，导致高等级在深色背景下对比度不足）
    static let dark: [ChartRGB] = [
        ChartRGB(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2E / 255), // 0 无记录
        ChartRGB(red: 0x2D / 255, green: 0x63 / 255, blue: 0xBA / 255), // 1
        ChartRGB(red: 0x3D / 255, green: 0x83 / 255, blue: 0xF6 / 255), // 2
        ChartRGB(red: 0x6E / 255, green: 0xA2 / 255, blue: 0xF8 / 255), // 3
        ChartRGB(red: 0x98 / 255, green: 0xBD / 255, blue: 0xFA / 255)  // 4
    ]

    /// 提高对比度（浅色）：拉开相邻等级差距
    static let lightHighContrast: [ChartRGB] = [
        ChartRGB(red: 0xDD / 255, green: 0xDD / 255, blue: 0xE3 / 255),
        ChartRGB(red: 0xC4 / 255, green: 0xD9 / 255, blue: 0xFC / 255),
        ChartRGB(red: 0x7D / 255, green: 0xAD / 255, blue: 0xFA / 255),
        ChartRGB(red: 0x2F / 255, green: 0x6F / 255, blue: 0xDC / 255),
        ChartRGB(red: 0x12 / 255, green: 0x45 / 255, blue: 0x93 / 255)
    ]

    /// 提高对比度（深色）
    static let darkHighContrast: [ChartRGB] = [
        ChartRGB(red: 0x1F / 255, green: 0x1F / 255, blue: 0x21 / 255),
        ChartRGB(red: 0x2A / 255, green: 0x5F / 255, blue: 0xB4 / 255),
        ChartRGB(red: 0x44 / 255, green: 0x8C / 255, blue: 0xFF / 255),
        ChartRGB(red: 0x86 / 255, green: 0xB6 / 255, blue: 0xFF / 255),
        ChartRGB(red: 0xCE / 255, green: 0xE1 / 255, blue: 0xFF / 255)
    ]

    /// 当前环境下的 5 级颜色（下标 0…4 = 等级）
    static func colors(scheme: ColorScheme, contrast: ColorSchemeContrast) -> [Color] {
        rgb(scheme: scheme, contrast: contrast).map(\.color)
    }

    static func rgb(scheme: ColorScheme, contrast: ColorSchemeContrast) -> [ChartRGB] {
        let highContrast = contrast == .increased
        switch (scheme, highContrast) {
        case (.dark, true): return darkHighContrast
        case (.dark, false): return dark
        case (_, true): return lightHighContrast
        default: return light
        }
    }
}
