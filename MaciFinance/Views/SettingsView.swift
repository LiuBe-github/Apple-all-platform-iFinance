//
//  SettingsView.swift
//  MaciFinance
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // MARK: Appearance Section
                settingsGroup(header: "外观", footer: "选择你喜欢的界面风格。") {
                    // Theme selection
                    HStack {
                        Label("主题模式", systemImage: "paintpalette")
                        Spacer()
                        Picker("", selection: $selectedTheme) {
                            Text("浅色").tag(ThemeMode.light)
                            Text("深色").tag(ThemeMode.dark)
                            Text("跟随系统").tag(ThemeMode.system)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                }

                // MARK: Language Section
                settingsGroup(header: "语言", footer: "选择应用显示语言。") {
                    HStack {
                        Label("语言", systemImage: "globe")
                        Spacer()
                        Picker("", selection: $appLanguage) {
                            ForEach(AppLanguage.allCases) { lang in Text(lang.displayName).tag(lang.rawValue) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                }

                // MARK: Data Section
                settingsGroup(header: "数据管理", footer: "Core Data 数据存储与同步设置。") {
                    HStack {
                        Label("数据文件位置", systemImage: "externaldrive")
                        Spacer()
                        Text("iFinance.sqlite")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("账单总数", systemImage: "list.bullet.clipboard")
                        Spacer()
                        Text("--")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: exportData) {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(role: .destructive, action: confirmClearData) {
                        Label("清除所有数据", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // MARK: About Section
                settingsGroup(header: "关于", footer: "") {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0 (Mac)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("平台", systemImage: "desktopcomputer")
                        Spacer()
                        Text("macOS")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "yensign.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("iFinance for Mac")
                                .font(.system(size: 16, weight: .semibold))
                            Text("简洁优雅的个人记账工具")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Group Helper

    @ViewBuilder
    private func settingsGroup<Content: View>(
        header: String,
        footer: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(header)
                .font(.system(size: 15, weight: .semibold))

            VStack(spacing: 8) {
                content()
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )

            if !footer.isEmpty {
                Text(footer)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Actions

    private func exportData() {
        // TODO: implement CSV/JSON export
        print("Export data...")
    }

    private func confirmClearData() {
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "此操作将永久删除所有账单数据，且无法恢复。确定要继续吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "确认删除")
        if alert.runModal() == .alertSecondButtonReturn {
            clearAllData()
        }
    }

    private func clearAllData() {
        let fetchRequest = Bill.fetchRequest() as NSFetchRequest<NSFetchRequestResult>
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try viewContext.execute(deleteRequest)
            try? viewContext.save()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }
}
