//
//  ThemeMode.swift
//  iFinance
//
//  主题模式设置 - 支持 iOS 和 macOS
//

import Foundation
import SwiftUI

/// 主题模式枚举
enum ThemeMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .light: return String(localized: "settings.theme_light", defaultValue: "浅色")
        case .dark: return String(localized: "settings.theme_dark", defaultValue: "深色")
        case .system: return String(localized: "settings.theme_system", defaultValue: "跟随系统")
        }
    }
}
