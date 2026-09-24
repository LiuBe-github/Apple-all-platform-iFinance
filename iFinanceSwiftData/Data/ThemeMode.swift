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
        case .light: return L10n.string("settings.theme_light")
        case .dark: return L10n.string("settings.theme_dark")
        case .system: return L10n.string("settings.theme_system")
        }
    }
}
