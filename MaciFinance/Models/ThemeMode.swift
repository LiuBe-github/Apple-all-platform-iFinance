//
//  ThemeMode.swift
//  MaciFinance
//

import Foundation
import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: Self { self }

    var displayName: String {
        switch self {
        // 复用四个语言包中已存在的通用主题文案（原先的 mac.settings.theme_* 未定义，会显示成原始 key）
        case .light: return L10n.string("settings.theme_light")
        case .dark: return L10n.string("settings.theme_dark")
        case .system: return L10n.string("settings.theme_system")
        }
    }
}
