//
//  L10n.swift
//  MaciFinance
//

import Foundation

enum L10n {
    /// 应用内统一的字符串获取函数
    /// 优先级：
    /// 1. 用户选择的 AppLanguage（非 system）→ 从对应 .lproj 读取
    /// 2. system → 用 NSLocalizedString（跟随系统）
    static func string(_ key: String) -> String {
        let selected = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.system.rawValue

        // 用户选择了固定语言 → 从对应语言包读取
        if selected != AppLanguage.system.rawValue,
           let path = Bundle.main.path(forResource: selected, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }

        // 跟随系统 → 用系统当前语言
        // 尝试用系统 locale 对应的 .lproj
        let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
        let systemRegion = Locale.current.region?.identifier ?? ""
        let candidates: [String]

        if !systemRegion.isEmpty {
            candidates = ["\(systemLang)_\(systemRegion)", systemLang, "en"]
        } else {
            candidates = [systemLang, "en"]
        }

        for lang in candidates {
            let normalized = normalizeLanguageIdentifier(lang)
            if let path = Bundle.main.path(forResource: normalized, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                let result = NSLocalizedString(key, bundle: bundle, comment: "")
                // 确保不是返回了 key 本身（说明该包确实有这个 key）
                if result != key { return result }
            }
        }

        // 完全找不到 → 返回 key（fallback）
        return NSLocalizedString(key, comment: "")
    }

    /// 将语言标识符标准化为 .lproj 目录名格式
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

    var nativeName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文 (Simplified Chinese)"
        case .zhHant: return "繁體中文 (Traditional Chinese)"
        case .en: return "English"
        case .ja: return "日本語 (Japanese)"
        }
    }
}

// MARK: - AppleLanguages 同步

/// 让系统本地化解析（`String(localized:)`、`NSLocalizedString`、系统控件文案）跟随 App 内选择的语言。
///
/// - 固定语言：覆盖 `UserDefaults["AppleLanguages"]`，重启后由系统按该语言解析 App bundle；
/// - 跟随系统：移除该覆盖，恢复系统默认语言。
enum LocalizationSync {
    private static let appleLanguagesKey = "AppleLanguages"

    /// 应用语言设置；返回是否有实际改动
    @discardableResult
    static func apply(_ language: AppLanguage) -> Bool {
        let current = UserDefaults.standard.stringArray(forKey: appleLanguagesKey)

        switch language {
        case .system:
            guard current != nil else { return false }
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
        default:
            guard current != [language.rawValue] else { return false }
            UserDefaults.standard.set([language.rawValue], forKey: appleLanguagesKey)
        }

        UserDefaults.standard.synchronize()
        return true
    }

    /// 启动时幂等同步：读取 `app_language` 并修正 AppleLanguages（覆盖老版本遗留的不一致）
    static func syncIfNeeded() {
        let stored = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.system.rawValue
        apply(AppLanguage(rawValue: stored) ?? .system)
    }
}
