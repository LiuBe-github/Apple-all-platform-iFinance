//
//  ThemeMode.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/8.
//

import Foundation
import UIKit
import SwiftUI

// 定义主题枚举
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
