//
//  SettingView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/31.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit
internal import CoreData

private struct BillCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

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

struct SettingView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.openURL) private var openURL

    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system

    @State private var exportDocument = BillCSVDocument()
    @State private var isExporting = false
    @State private var isImporting = false

    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var showResultAlert = false

    private let feedbackEmail = "support@ifinance.app"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? String(localized: "common.unknown")
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? String(localized: "common.unknown")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                Form {
                    Section("settings.about_you") {
                        NavigationLink(destination: ProfileView()) {
                            Label("settings.profile", systemImage: "person.circle")
                        }
                    }

                    Section("settings.icloud_section") {
                        NavigationLink(destination: iCloudSyncView()) {
                            Label("settings.icloud", systemImage: "icloud")
                        }
                    }

                    Section("settings.import_export") {
                        Button {
                            prepareExportDocument()
                        } label: {
                            Label("settings.export_csv", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            isImporting = true
                        } label: {
                            Label("settings.import_csv", systemImage: "square.and.arrow.down")
                        }
                    }

                    Section("settings.appearance") {
                        Picker("settings.theme_mode", selection: $selectedTheme) {
                            Text("settings.theme_light").tag(ThemeMode.light)
                            Text("settings.theme_dark").tag(ThemeMode.dark)
                            Text("settings.theme_system").tag(ThemeMode.system)
                        }
                        .pickerStyle(.menu)
                    }

                    Section("settings.general") {
                        NavigationLink("settings.language") {
                            LanguageSettingView()
                        }
                    }

                    Section("settings.about") {
                        NavigationLink {
                            HelpFeedbackView(feedbackEmail: feedbackEmail, openURL: openURL)
                        } label: {
                            Label("settings.help_feedback", systemImage: "questionmark.bubble")
                        }

                        NavigationLink {
                            AboutAppView(version: appVersion, build: buildNumber)
                        } label: {
                            Label("settings.about_us", systemImage: "info.circle")
                        }

                        HStack {
                            Text("settings.version")
                            Spacer()
                            Text("v\(appVersion) (\(buildNumber))")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            authManager.logout()
                        } label: {
                            Text("profile.logout")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("settings.title")
            .scrollIndicators(.automatic)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HeaderView(isTransactionView: false)
                }
            }
            .navigationBarBackButtonHidden(true)
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "iFinance-bills-\(Date().formatted(.dateTime.year().month().day()))"
            ) { result in
                switch result {
                case .success:
                    showResult(title: String(localized: "settings.export_success"), message: String(localized: "settings.export_success_msg"))
                case .failure(let error):
                    showResult(title: String(localized: "settings.export_failed"), message: error.localizedDescription)
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    importCSV(from: url)
                case .failure(let error):
                    showResult(title: String(localized: "settings.import_failed"), message: error.localizedDescription)
                }
            }
            .alert(resultTitle, isPresented: $showResultAlert) {
                Button("common.ok", role: .cancel) { }
            } message: {
                Text(resultMessage)
            }
        }
    }

    private func prepareExportDocument() {
        do {
            let request: NSFetchRequest<Bill> = Bill.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.date, ascending: true)]
            let bills = try viewContext.fetch(request)

            let iso = ISO8601DateFormatter()
            var lines = ["date,type,category,amount,note"]

            for bill in bills {
                let date = iso.string(from: bill.date ?? Date())
                let type = csvEscape(bill.type ?? "")
                let category = csvEscape(bill.category ?? "")
                let amount = (bill.amount?.stringValue ?? "0")
                let note = csvEscape(bill.note ?? "")
                lines.append("\(date),\(type),\(category),\(amount),\(note)")
            }

            exportDocument = BillCSVDocument(text: lines.joined(separator: "\n"))
            isExporting = true
        } catch {
            showResult(title: String(localized: "settings.export_failed"), message: error.localizedDescription)
        }
    }

    private func importCSV(from url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = parseCSVRows(content)
            guard rows.count > 1 else {
                showResult(title: String(localized: "settings.import_failed"), message: String(localized: "settings.import_invalid"))
                return
            }

            let iso = ISO8601DateFormatter()
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
            fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            var inserted = 0
            var skipped = 0

            for row in rows.dropFirst() {
                guard row.count >= 5 else {
                    skipped += 1
                    continue
                }

                let dateString = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let type = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let category = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let amountString = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let note = row[4].trimmingCharacters(in: .whitespacesAndNewlines)

                guard ["income", "expenditure", "transfer"].contains(type) else {
                    skipped += 1
                    continue
                }

                let date = iso.date(from: dateString) ?? fallbackFormatter.date(from: dateString)
                guard let amountDecimal = Decimal(string: amountString, locale: Locale(identifier: "en_US_POSIX")) else {
                    skipped += 1
                    continue
                }

                let newBill = Bill(context: viewContext)
                newBill.date = date ?? Date()
                newBill.type = type
                newBill.category = category.isEmpty ? nil : category
                newBill.note = note.isEmpty ? nil : note
                newBill.amount = NSDecimalNumber(decimal: amountDecimal)
                inserted += 1
            }

            if viewContext.hasChanges {
                try viewContext.save()
            }

            showResult(
                title: String(localized: "settings.import_done"),
                message: String(
                    format: NSLocalizedString("settings.import_done_msg", comment: ""),
                    inserted,
                    skipped
                )
            )
        } catch {
            showResult(title: String(localized: "settings.import_failed"), message: error.localizedDescription)
        }
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func parseCSVRows(_ input: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        let chars = Array(input)
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            if ch == "\"" {
                if insideQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    currentField.append("\"")
                    i += 1
                } else {
                    insideQuotes.toggle()
                }
            } else if ch == "," && !insideQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if ch == "\n" && !insideQuotes {
                currentRow.append(currentField)
                if !currentRow.allSatisfy({ $0.isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow = []
                currentField = ""
            } else if ch == "\r" {
                // ignore CR
            } else {
                currentField.append(ch)
            }

            i += 1
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }

    private func showResult(title: String, message: String) {
        resultTitle = title
        resultMessage = message
        showResultAlert = true
    }
}

private struct HelpFeedbackView: View {
    let feedbackEmail: String
    let openURL: OpenURLAction

    @State private var copied = false

    var body: some View {
        List {
            Section("settings.contact") {
                HStack {
                    Text("settings.feedback_email")
                    Spacer()
                    Text(feedbackEmail)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                Button {
                    UIPasteboard.general.string = feedbackEmail
                    copied = true
                } label: {
                    Label(String(localized: copied ? "settings.copied_email" : "settings.copy_email"), systemImage: copied ? "checkmark.circle" : "doc.on.doc")
                }

                Button {
                    if let url = URL(string: "mailto:\(feedbackEmail)?subject=iFinance%20Feedback") {
                        openURL(url)
                    }
                } label: {
                    Label("settings.send_email", systemImage: "envelope")
                }
            }

            Section("settings.faq") {
                Text("settings.faq_1")
                Text("settings.faq_2")
                Text("settings.faq_3")
            }
        }
        .navigationTitle("settings.help_feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutAppView: View {
    let version: String
    let build: String

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text("iFinance")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("settings.about_desc")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("settings.version_section") {
                HStack {
                    Text("settings.version_number")
                    Spacer()
                    Text(version)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("settings.build_number")
                    Spacer()
                    Text(build)
                        .foregroundStyle(.secondary)
                }
            }

            Section("settings.disclaimer") {
                Text("settings.disclaimer_text")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("settings.about_us")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingView()
}
