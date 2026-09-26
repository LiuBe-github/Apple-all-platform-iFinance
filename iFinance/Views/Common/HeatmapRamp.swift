//
//  HeatmapRamp.swift
//  iFinance
//
//  热力图 5 级色阶（0 = 无记录 + 1…4 级）。
//  - 默认配色**沿用改版前的原始取值**（用户要求「我要原来的颜色」）；只有系统开启
//    「提高对比度」时才切到高对比变体（等级亮度差更大）
//  - R15：等级之间还有格子间距做视觉分隔
//  色阶以 RGB 元组定义，便于单测直接断言亮度与对比度。
//
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

enum HeatmapRamp {

    /// 改版前的原始色阶（0 = 无记录 + 4 级蓝色，深浅模式共用）
    static let light: [ChartRGB] = [
        ChartRGB(red: 0.90, green: 0.90, blue: 0.92),  // 0 无记录（systemGray5 近似）
        ChartRGB(red: 0.79, green: 0.88, blue: 1.00),  // 1
        ChartRGB(red: 0.56, green: 0.75, blue: 0.98),  // 2
        ChartRGB(red: 0.31, green: 0.56, blue: 0.95),  // 3
        ChartRGB(red: 0.15, green: 0.42, blue: 0.86)   // 4
    ]

    static let dark = light

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
