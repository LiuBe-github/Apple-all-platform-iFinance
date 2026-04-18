//
//  L10n.swift
//  MaciFinance
//

import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        let selected = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.system.rawValue
        guard selected != AppLanguage.system.rawValue else {
            return NSLocalizedString(key, comment: "")
        }

        guard let path = Bundle.main.path(forResource: selected, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"
    case ja = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}
