//
//  L10n.swift
//  WatchiFinance Watch App
//

import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        let selected = UserDefaults.standard.string(forKey: "app_language") ?? "system"

        // 用户选择了固定语言 → 从对应语言包读取
        if selected != "system",
           let path = Bundle.main.path(forResource: selected, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }

        // 跟随系统
        let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
        let candidates = ["\(systemLang)", "en"]

        for lang in candidates {
            let normalized = normalizeLanguageIdentifier(lang)
            if let path = Bundle.main.path(forResource: normalized, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                let result = NSLocalizedString(key, bundle: bundle, comment: "")
                if result != key { return result }
            }
        }

        return NSLocalizedString(key, comment: "")
    }

    private static func normalizeLanguageIdentifier(_ identifier: String) -> String {
        switch identifier.lowercased() {
        case "zh":     return "zh-Hans"
        case "zh-cn", "zh-hans": return "zh-Hans"
        case "zh-tw", "zh-hant", "zh-hk": return "zh-Hant"
        case "en":     return "en"
        case "ja":     return "ja"
        default:        return identifier
        }
    }
}
