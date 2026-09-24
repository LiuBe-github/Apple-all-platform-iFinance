//
//  SettingView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/31.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit
import SwiftData

// MARK: - CSV 文档

private struct BillCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String = "") { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let content = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = content
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// MARK: - 设置分组

struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xxl)
            .padding(.bottom, AppSpacing.md)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .padding(.horizontal, AppSpacing.xl)
        }
    }
}

// MARK: - 设置行

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            HapticManager.shared.light()
            action?()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.22), iconColor.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(iconColor.opacity(0.2), lineWidth: 0.8)
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).foregroundStyle(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.97))
    }
}

// MARK: - 分隔线

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(UIColor.separator).opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }
}

// MARK: - 帮助与反馈视图

private struct HelpFeedbackView: View {
    let feedbackEmail: String

    @Environment(\.openURL) private var openURL
    @State private var copied = false

    var body: some View {
        List {
            Section(L10n.string("settings.contact")) {
                HStack {
                    Text(L10n.string("settings.feedback_email"))
                    Spacer()
                    Text(feedbackEmail).foregroundStyle(.secondary).font(.footnote)
                }

                Button {
                    UIPasteboard.general.string = feedbackEmail
                    copied = true
                } label: {
                    Label(
                        L10n.string(copied ? "settings.copied_email" : "settings.copy_email"),
                        systemImage: copied ? "checkmark.circle" : "doc.on.doc"
                    )
                }

                Button {
                    if let url = URL(string: "mailto:\(feedbackEmail)?subject=iFinance%20Feedback") {
                        openURL(url)
                    }
                } label: {
                    Label(L10n.string("settings.send_email"), systemImage: "envelope")
                }
            }

            Section(L10n.string("settings.faq")) {
                Text(L10n.string("settings.faq_1"))
                Text(L10n.string("settings.faq_2"))
                Text(L10n.string("settings.faq_3"))
            }
        }
        .navigationTitle(L10n.string("settings.help_feedback"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 关于应用视图

private struct AboutAppView: View {
    let version: String
    let build: String

    var body: some View {
        List {
            Section {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text("iFinance").font(.title2).fontWeight(.bold)
                    Text(L10n.string("settings.about_desc"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
            }

            Section(L10n.string("settings.version_section")) {
                HStack {
                    Text(L10n.string("settings.version_number")); Spacer(); Text(version).foregroundStyle(.secondary)
                }
                HStack {
                    Text(L10n.string("settings.build_number")); Spacer(); Text(build).foregroundStyle(.secondary)
                }
            }

            Section(L10n.string("settings.disclaimer")) {
                Text(L10n.string("settings.disclaimer_text")).font(.footnote).foregroundStyle(.secondary)
            }

            Section(L10n.string("settings.wechat_section")) {
                VStack(spacing: AppSpacing.sm) {
                    Image("MyWeChat")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 180, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                    Text(L10n.string("settings.wechat_desc")).font(.footnote).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, AppSpacing.sm)
            }
        }
        .navigationTitle(L10n.string("settings.about_me"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 主视图

struct SettingView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.modelContext) private var viewContext

    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system

    @State private var exportDocument = BillCSVDocument()
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var showResultAlert = false

    @State private var navigateToProfile = false
    // iCloud 同步已暂时禁用
    // @State private var navigateToICloud = false
    @State private var navigateToHelp = false
    @State private var navigateToAbout = false
    @State private var navigateToLanguage = false
    @State private var showDeleteAccountConfirmation = false

    // 生物识别锁相关状态
    @StateObject private var biometricLock = BiometricLockManager.shared
    @State private var isTogglingLock = false
    /// 本地 Toggle 状态（与 AppStorage 解耦，避免竞态）
    @State private var lockToggleValue: Bool = false

    private let feedbackEmail = "liubeol@outlook.com"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? L10n.string("common.unknown")
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? L10n.string("common.unknown")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        SettingsProfileHeaderView()

                        // 个人信息
                        SettingsGroup(title: L10n.string("settings.about_you"), icon: "person.fill", iconColor: .blue) {
                            SettingsRow(icon: "person.circle.fill", iconColor: .blue, title: L10n.string("settings.profile")) {
                                navigateToProfile = true
                            }
                            SettingsDivider()
                            Button {
                                HapticManager.shared.medium()
                                showDeleteAccountConfirmation = true
                            } label: {
                                HStack(spacing: AppSpacing.md) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.red.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "person.crop.circle.badge.minus")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.red)
                                    }
                                    Text(L10n.string("settings.delete_account"))
                                        .font(.body).foregroundStyle(.red)
                                    Spacer()
                                }
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.md)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        // 数据同步（iCloud 同步已暂时禁用，需付费开发者账号）
                        // SettingsGroup(title: L10n.string("settings.icloud_section"), icon: "icloud.fill", iconColor: .cyan) {
                        //     SettingsRow(icon: "icloud", iconColor: .cyan, title: L10n.string("settings.icloud")) {
                        //         navigateToICloud = true
                        //     }
                        // }

                        // 导入导出
                        SettingsGroup(title: L10n.string("settings.import_export"), icon: "doc.fill", iconColor: .green) {
                            SettingsRow(icon: "square.and.arrow.up", iconColor: .green, title: L10n.string("settings.export_csv")) {
                                prepareExportDocument()
                            }
                            SettingsDivider()
                            SettingsRow(icon: "square.and.arrow.down", iconColor: .orange, title: L10n.string("settings.import_csv")) {
                                isImporting = true
                            }
                        }

                        // 外观
                        SettingsGroup(title: L10n.string("settings.appearance"), icon: "paintbrush.fill", iconColor: .purple) {
                            SettingsThemeSelectorView(selectedTheme: $selectedTheme)
                        }

                        // 通用
                        SettingsGroup(title: L10n.string("settings.general"), icon: "gearshape.fill", iconColor: .gray) {
                            // 生物识别锁
                            if biometricLock.isBiometricAvailable {
                                HStack(spacing: AppSpacing.md) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(.indigo.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: biometricLock.biometricIconName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.indigo)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L10n.string("settings.biometric_lock"))
                                            .font(.body).foregroundStyle(.primary)
                                        Text(biometricLock.biometricDisplayName + L10n.string("settings.biometric_lock_desc"))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $lockToggleValue)
                                        .labelsHidden()
                                        .tint(.indigo)
                                        .disabled(isTogglingLock)
                                        .onChange(of: lockToggleValue) { _, newValue in
                                            handleLockToggle(newValue)
                                        }
                                }
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.md)
                            }

                            SettingsRow(icon: "globe", iconColor: .indigo, title: L10n.string("settings.language")) {
                                navigateToLanguage = true
                            }
                        }

                        // 关于
                        SettingsGroup(title: L10n.string("settings.about"), icon: "info.circle.fill", iconColor: .blue) {
                            SettingsRow(icon: "questionmark.bubble", iconColor: .blue, title: L10n.string("settings.help_feedback"), subtitle: feedbackEmail) {
                                navigateToHelp = true
                            }
                            SettingsDivider()
                            SettingsRow(icon: "info.circle", iconColor: .blue, title: L10n.string("settings.about_me"), subtitle: "v\(appVersion) (\(buildNumber))") {
                                navigateToAbout = true
                            }
                        }

                        // 登出
                        logoutButton.padding(.top, AppSpacing.xxl).padding(.bottom, 120)
                    }
                }
                .appContentWidth(AppLayout.formMaxWidth)
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $navigateToProfile) {
                ProfileView().toolbar(.hidden, for: .tabBar).navigationTitle(L10n.string("settings.profile"))
            }
            // iCloud 同步已暂时禁用
            // .navigationDestination(isPresented: $navigateToICloud) {
            //     iCloudSyncView().toolbar(.hidden, for: .tabBar).navigationTitle(L10n.string("settings.icloud"))
            // }
            .navigationDestination(isPresented: $navigateToHelp) {
                HelpFeedbackView(feedbackEmail: feedbackEmail).toolbar(.hidden, for: .tabBar)
            }
            .navigationDestination(isPresented: $navigateToAbout) {
                AboutAppView(version: appVersion, build: buildNumber).toolbar(.hidden, for: .tabBar)
            }
            .navigationDestination(isPresented: $navigateToLanguage) {
                LanguageSettingView().toolbar(.hidden, for: .tabBar).navigationTitle(L10n.string("settings.language"))
            }
            .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .commaSeparatedText, defaultFilename: "iFinance-bills-\(Date().formatted(.dateTime.year().month().day()))") { result in
                switch result {
                case .success: showResult(title: L10n.string("settings.export_success"), message: L10n.string("settings.export_success_msg"))
                case .failure(let e): showResult(title: L10n.string("settings.export_failed"), message: e.localizedDescription)
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText, .plainText], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): guard let u = urls.first else { return }; importCSV(from: u)
                case .failure(let e): showResult(title: L10n.string("settings.import_failed"), message: e.localizedDescription)
                }
            }
            .alert(resultTitle, isPresented: $showResultAlert) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(resultMessage)
            }
            .alert(L10n.string("settings.delete_account_confirm_title"), isPresented: $showDeleteAccountConfirmation) {
                Button(L10n.string("settings.delete_account_cancel"), role: .cancel) {}
                Button(L10n.string("settings.delete_account_confirm"), role: .destructive) {
                    HapticManager.shared.heavy()
                    authManager.deleteAccount()
                }
            } message: {
                Text(L10n.string("settings.delete_account_confirm_message"))
            }
            .onAppear {
                biometricLock.evaluateBiometricCapability()
                lockToggleValue = biometricLock.isLockEnabled
            }
        }
    }

    // MARK: - 头像区域


    // MARK: - 主题选择器



    // MARK: - 生物识别锁辅助

    /// 处理生物识别锁开关切换
    private func handleLockToggle(_ newValue: Bool) {
        HapticManager.shared.medium()
        isTogglingLock = true
        Task { [weak biometricLock] in
            guard let lock = biometricLock else { return }
            var success = false
            if newValue {
                // 开启：启用时需要生物识别验证
                success = await lock.enableLock()
            } else {
                // 关闭：禁用时也需要生物识别验证（失败 2 次后降级为密码）
                success = await lock.disableLock()
            }
            await MainActor.run {
                isTogglingLock = false
                // 无论开启还是关闭，只要验证失败就回滚 Toggle
                if !success {
                    lockToggleValue.toggle()
                }
            }
        }
    }

    // MARK: - 登出按钮

    private var logoutButton: some View {
        Button { HapticManager.shared.medium(); authManager.logout() } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .medium))
                Text(L10n.string("profile.logout")).font(.body.weight(.medium))
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.lg)
            .background(RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous).fill(Color(UIColor.secondarySystemGroupedBackground)))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.18), lineWidth: 0.8)
            )
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.97))
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - 导出/导入逻辑

    private func prepareExportDocument() {
        do {
            let descriptor = FetchDescriptor<Bill>(sortBy: [SortDescriptor(\Bill.date, order: .forward)])
            let bills = try viewContext.fetch(descriptor)
            let iso = ISO8601DateFormatter()
            var lines = ["date,type,category,amount,note"]
            for b in bills {
                let d = iso.string(from: b.date ?? Date())
                lines.append("\(d),\(csvEscape(b.type ?? "")),\(csvEscape(b.category ?? "")),\(b.amountString),\(csvEscape(b.note ?? ""))")
            }
            exportDocument = BillCSVDocument(text: lines.joined(separator: "\n"))
            isExporting = true
        } catch {
            showResult(title: L10n.string("settings.export_failed"), message: error.localizedDescription)
        }
    }

    private func importCSV(from url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = parseCSVRows(content)
            guard rows.count > 1 else {
                showResult(title: L10n.string("settings.import_failed"), message: L10n.string("settings.import_invalid"))
                return
            }
            let iso = ISO8601DateFormatter()
            let fallback = DateFormatter()
            fallback.locale = Locale(identifier: "en_US_POSIX")
            fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
            var inserted = 0, skipped = 0
            for row in rows.dropFirst() {
                guard row.count >= 5 else {
                    skipped += 1
                    continue
                }
                let type = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
                guard ["income","expenditure","transfer"].contains(type) else {
                    skipped += 1
                    continue
                }
                let date = iso.date(from: row[0].trimmingCharacters(in: .whitespacesAndNewlines)) ?? fallback.date(from: row[0])
                guard let amt = Decimal(string: row[3], locale: Locale(identifier: "en_US_POSIX")) else {
                    skipped += 1
                    continue
                }
                let identifier = AuthManager.shared.userIdentifier
                let bill = Bill(
                    amount: amt,
                    type: type,
                    category: row[2].isEmpty ? nil : row[2],
                    note: row[4].isEmpty ? nil : row[4],
                    date: date ?? Date(),
                    createdBy: identifier,
                    updatedBy: identifier
                )
                viewContext.insert(bill)
                inserted += 1
            }
            if viewContext.hasChanges {
                try viewContext.save()
            }
            showResult(title: L10n.string("settings.import_done"), message: String(format: L10n.string("settings.import_done_msg"), inserted, skipped))
        } catch {
            showResult(title: L10n.string("settings.import_failed"), message: error.localizedDescription)
        }
    }

    private func csvEscape(_ v: String) -> String {
        v.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private func parseCSVRows(_ input: String) -> [[String]] {
        var rows: [[String]] = [], curRow: [String] = [], curField = "", inQ = false
        let chars = Array(input)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if ch == "\"" {
                if inQ && i + 1 < chars.count && chars[i + 1] == "\"" {
                    curField.append("\"")
                    i += 1
                } else {
                    inQ.toggle()
                }
            } else if ch == "," && !inQ {
                curRow.append(curField); curField = ""
            } else if ch == "\n" && !inQ {
                curRow.append(curField)
                if !curRow.allSatisfy({ $0.isEmpty }) {
                    rows.append(curRow)
                }
                curRow = []
                curField = ""
            }
            else if ch != "\r" {
                curField.append(ch)
            }
            i += 1
        }
        if !curField.isEmpty || !curRow.isEmpty {
            curRow.append(curField)
            if !curRow.allSatisfy({ $0.isEmpty }) {
                rows.append(curRow)
            }
        }
        return rows
    }

    private func showResult(title: String, message: String) {
        resultTitle = title; resultMessage = message; showResultAlert = true
    }
}

#Preview {
    SettingView()
}


// MARK: - 设置页子视图（拆分以减少整页重算）

/// 头部：头像 + 昵称（只依赖 authManager，不受设置页其它状态影响）
private struct SettingsProfileHeaderView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showSignatureEditor = false

    /// 未设置签名时显示可点击的占位提示
    private var signatureText: String {
        let value = authManager.signature
        return value.isEmpty ? L10n.string("profile.signature_placeholder") : value
    }

    var body: some View {
        Button {
            HapticManager.shared.light()
            showSignatureEditor = true
        } label: {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.35), Color.purple.opacity(0.25), Color.pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )

                    if let uiImage = AvatarImageCache.shared.image(for: authManager.avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 66, height: 66)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 66))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(authManager.nickname).font(.title2.weight(.bold))

                    HStack(spacing: AppSpacing.xs) {
                        Text(signatureText)
                            .font(.subheadline)
                            .foregroundStyle(authManager.signature.isEmpty ? .tertiary : .secondary)
                            .lineLimit(1)

                        Image(systemName: "pencil")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(AppSpacing.xxl)
        .padding(.top, AppSpacing.sm)
        .sheet(isPresented: $showSignatureEditor) {
            EditSignatureView(initial: authManager.signature)
                .environmentObject(authManager)
        }
    }
}

/// 主题选择器（只依赖主题绑定）
private struct SettingsThemeSelectorView: View {
    @Binding var selectedTheme: ThemeMode
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ThemeMode.allCases, id: \.self) { theme in
                Button {
                    HapticManager.shared.selectionChanged()
                    withAnimation(AppMotion.standard) { selectedTheme = theme }
                } label: {
                    VStack(spacing: AppSpacing.sm) {
                        ZStack {
                            if selectedTheme == theme {
                                Circle()
                                    .fill(themeColor(theme).opacity(0.16))
                                    .frame(width: 46, height: 46)
                                    .matchedGeometryEffect(id: "themeSelection", in: namespace)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(themeColor(theme).opacity(0.45), lineWidth: 1.2)
                                            .matchedGeometryEffect(id: "themeSelectionRing", in: namespace)
                                    )
                            } else {
                                Circle().fill(Color.primary.opacity(0.05)).frame(width: 46, height: 46)
                            }
                            Image(systemName: themeIcon(theme))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(themeColor(theme))
                                .symbolEffect(.bounce, value: selectedTheme == theme)
                        }
                        Text(themeTitle(theme)).font(.caption2.weight(.medium))
                            .foregroundStyle(selectedTheme == theme ? themeColor(theme) : .secondary)
                    }
                }
                .buttonStyle(ScaleButtonStyle(pressedScale: 0.9))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.lg)
    }

    private func themeColor(_ t: ThemeMode) -> Color {
        switch t { case .light: return .orange; case .dark: return .indigo; case .system: return .blue }
    }
    private func themeIcon(_ t: ThemeMode) -> String {
        switch t { case .light: return "sun.max.fill"; case .dark: return "moon.fill"; case .system: return "circle.lefthalf.filled" }
    }
    private func themeTitle(_ t: ThemeMode) -> String {
        switch t {
        case .light: return L10n.string("settings.theme_light")
        case .dark: return L10n.string("settings.theme_dark")
        case .system: return L10n.string("settings.theme_system")
        }
    }
}
