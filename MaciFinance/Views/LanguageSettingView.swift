//
//  LanguageSettingView.swift
//  MaciFinance
//
//  Mac 端语言设置视图
//

import SwiftUI

struct MacLanguageSettingView: View {
    @AppStorage("app_language") private var selectedLanguage: String = AppLanguage.system.rawValue
    @State private var showRestartAlert = false
    @State private var pendingLanguage: AppLanguage?

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .system
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("settings.language.select"))
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { language in
                    languageRow(for: language)
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 360)
        .alert(L10n.string("settings.language.restart_title"), isPresented: $showRestartAlert) {
            Button(L10n.string("common.confirm"), role: .destructive) {
                if let lang = pendingLanguage {
                    selectedLanguage = lang.rawValue
                }
                restartApp()
            }
            Button(L10n.string("common.cancel"), role: .cancel) {
                pendingLanguage = nil
            }
        } message: {
            Text(L10n.string("settings.language.restart_message"))
        }
    }

    private func languageRow(for language: AppLanguage) -> some View {
        Button {
            selectLanguage(language)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.system(size: 14, weight: .medium))
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                currentLanguage == language ?
                Color.accentColor.opacity(0.1) :
                Color(nsColor: .controlBackgroundColor)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func selectLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        pendingLanguage = language
        showRestartAlert = true
    }

    /// 重启 App
    private func restartApp() {
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    MacLanguageSettingView()
}
