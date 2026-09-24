//
//  LocalizationHelper.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/25.
//

import SwiftUI
import os.log

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
    
    var id: String {
        rawValue
    }
    
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .zhHans:
            return "简体中文"
        case .zhHant:
            return "繁體中文"
        case .en:
            return "English"
        case .ja:
            return "日本語"
        }
    }
    
    var nativeName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .zhHans:
            return "简体中文 (Simplified Chinese)"
        case .zhHant:
            return "繁體中文 (Traditional Chinese)"
        case .en:
            return "English"
        case .ja:
            return "日本語 (Japanese)"
        }
    }
}

// MARK: - AppleLanguages 同步

/// 让系统本地化解析（`String(localized:)`、`NSLocalizedString`、系统控件文案）跟随 App 内选择的语言。
///
/// - 固定语言：覆盖 `UserDefaults["AppleLanguages"]`，重启后由系统按该语言解析 App bundle；
/// - 跟随系统：移除该覆盖，恢复系统默认语言。
///
/// 说明：`AppleLanguages` 是系统读取的语言偏好键（非官方 API），业界广泛使用；
/// 写入后必须重启进程才生效——这与现有语言切换流程（`exit(0)` 重启）一致。
enum LocalizationSync {
    private static let appleLanguagesKey = "AppleLanguages"
    private static let logger = Logger(subsystem: "com.liube.ifinance", category: "Localization")

    /// 应用语言设置；返回是否有实际改动
    @discardableResult
    static func apply(_ language: AppLanguage) -> Bool {
        let current = UserDefaults.standard.stringArray(forKey: appleLanguagesKey)

        let changed: Bool
        switch language {
        case .system:
            guard current != nil else { return false }
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
            changed = true
        default:
            guard current != [language.rawValue] else { return false }
            UserDefaults.standard.set([language.rawValue], forKey: appleLanguagesKey)
            changed = true
        }

        UserDefaults.standard.synchronize()
        logger.notice("AppleLanguages 已同步为 \(language.rawValue, privacy: .public)（原值 \(current?.joined(separator: ",") ?? "nil", privacy: .public)）")
        return changed
    }

    /// 启动时幂等同步：读取 `app_language` 并修正 AppleLanguages（覆盖老版本遗留的不一致）
    static func syncIfNeeded() {
        let stored = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.system.rawValue
        logger.notice("启动同步：app_language=\(stored, privacy: .public)")
        apply(AppLanguage(rawValue: stored) ?? .system)
    }
}

struct LanguageSettingView: View {
    @AppStorage("app_language") private var selectedLanguage: String = AppLanguage.system.rawValue
    @State private var showRestartAlert = false
    @State private var pendingLanguage: AppLanguage?

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .system
    }

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        selectLanguage(language)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.primary)

                                if language != .system {
                                    Text(language.nativeName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(L10n.string("settings.language.select"))
                    .font(.subheadline)
                    .fontWeight(.medium)
            } footer: {
                Text(L10n.string("settings.language.footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.string("settings.language"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.string("settings.language.restart_title"), isPresented: $showRestartAlert) {
            Button(L10n.string("common.confirm"), role: .destructive) {
                if let lang = pendingLanguage {
                    selectedLanguage = lang.rawValue
                }
                // 触发 App 重启
                restartApp()
            }
            Button(L10n.string("common.cancel"), role: .cancel) {
                pendingLanguage = nil
            }
        } message: {
            Text(L10n.string("settings.language.restart_message"))
        }
    }

    private func selectLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        pendingLanguage = language
        showRestartAlert = true
    }

    /// 重启 App：退出当前进程，iOS 会自动重新拉起 App
    private func restartApp() {
        HapticManager.shared.success()
        // 让系统本地化解析（String(localized:)、系统控件）跟随本次选择的语言，重启后生效
        LocalizationSync.apply(currentLanguage)
        // 清除 SwiftUI 的 scene 以确保重启时状态干净
        exit(0)
    }
}

#Preview {
    NavigationStack {
        LanguageSettingView()
    }
}
