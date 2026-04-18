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
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        }
    }
}
