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
        case .light: return L10n.string("mac.settings.theme_light")
        case .dark: return L10n.string("mac.settings.theme_dark")
        case .system: return L10n.string("mac.settings.theme_system")
        }
    }
}
