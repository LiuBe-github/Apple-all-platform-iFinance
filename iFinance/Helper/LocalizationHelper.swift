//
//  LanguageSettingView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/25.
//

import SwiftUI

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

struct LanguageSettingView: View {
    @AppStorage("app_language") private var selectedLanguage: String = AppLanguage.system.rawValue
    
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
                Text("settings.language.select")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } footer: {
                Text("settings.language.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("settings.language")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func selectLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else {
            return
        }
        
        selectedLanguage = language.rawValue
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    NavigationStack {
        LanguageSettingView()
    }
}
