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
        LanguageRowView(
            language: language,
            isCurrent: currentLanguage == language
        ) {
            selectLanguage(language)
        }
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

// MARK: - 语言行

private struct LanguageRowView: View {
    let language: AppLanguage
    let isCurrent: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
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

                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue)
                        .symbolEffect(.bounce, value: isCurrent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isCurrent
                ? Color.accentColor.opacity(0.12)
                : (isHovering ? Color.primary.opacity(0.06) : Color(nsColor: .controlBackgroundColor))
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isCurrent ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.97))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    MacLanguageSettingView()
}
