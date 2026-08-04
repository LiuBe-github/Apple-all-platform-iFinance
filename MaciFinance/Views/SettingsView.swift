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
                settingsGroup(header: L10n.string("mac.settings.appearance"), footer: L10n.string("mac.settings.appearance_desc")) {
                    // Theme selection
                    HStack {
                        Label(L10n.string("mac.settings.theme_mode"), systemImage: "paintpalette")
                        Spacer()
                        Picker("", selection: $selectedTheme) {
                            Text(ThemeMode.light.displayName).tag(ThemeMode.light)
                            Text(ThemeMode.dark.displayName).tag(ThemeMode.dark)
                            Text(ThemeMode.system.displayName).tag(ThemeMode.system)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                }

                // MARK: Language Section
                settingsGroup(header: L10n.string("settings.language"), footer: L10n.string("settings.language.footer")) {
                    NavigationLink {
                        MacLanguageSettingView()
                    } label: {
                        HStack {
                            Label(L10n.string("settings.language"), systemImage: "globe")
                            Spacer()
                            Text(AppLanguage(rawValue: appLanguage)?.displayName ?? AppLanguage.system.displayName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // MARK: iCloud Sync Section（暂时禁用，需付费开发者账号）
                // settingsGroup(header: L10n.string("settings.icloud"), footer: L10n.string("icloud.sync_description")) {
                //     MaciCloudSyncView()
                //         .frame(height: 200)
                // }

                // MARK: Data Section
                settingsGroup(header: L10n.string("mac.settings.data_management"), footer: "") {
                    HStack {
                        Label(L10n.string("mac.settings.data_file_location"), systemImage: "externaldrive")
                        Spacer()
                        Text("iFinance.sqlite")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label(L10n.string("mac.settings.bill_total_count"), systemImage: "list.bullet.clipboard")
                        Spacer()
                        Text("--")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: exportData) {
                        Label(L10n.string("mac.settings.export_data"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(role: .destructive, action: confirmClearData) {
                        Label(L10n.string("mac.settings.clear_all_data"), systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: generateTestData) {
                        Label(L10n.string("mac.settings.generate_test_data"), systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // MARK: About Section
                settingsGroup(header: L10n.string("mac.settings.about"), footer: "") {
                    HStack {
                        Label(L10n.string("mac.settings.version"), systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0 (Mac)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label(L10n.string("mac.settings.platform"), systemImage: "desktopcomputer")
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
                            Text(L10n.string("mac.settings.app_description"))
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
        alert.messageText = L10n.string("mac.settings.confirm_delete")
        alert.informativeText = L10n.string("mac.settings.confirm_delete_message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("mac.settings.cancel"))
        alert.addButton(withTitle: L10n.string("mac.settings.confirm"))
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
    
    // MARK: - Test Data Generation
    
    private func generateTestData() {
        let confirmAlert = NSAlert()
        confirmAlert.messageText = L10n.string("mac.settings.generate_test_title")
        confirmAlert.informativeText = L10n.string("mac.settings.generate_test_message")
        confirmAlert.alertStyle = .informational
        confirmAlert.addButton(withTitle: L10n.string("mac.settings.cancel"))
        confirmAlert.addButton(withTitle: L10n.string("mac.settings.generate"))
        
        guard confirmAlert.runModal() == .alertSecondButtonReturn else { return }
        
        // 创建后台上下文进行批量插入
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        backgroundContext.perform {
            self.generateBillsInBackground(context: backgroundContext)
        }
    }
    
    private func generateBillsInBackground(context: NSManagedObjectContext) {
        let billCount = 1000
        let calendar = Calendar.current
        let now = Date()
        let userId = PersistenceController.currentUserIdentifier
        
        // 支出分类及金额范围
        let expenditureData: [(category: String, range: ClosedRange<Double>, notes: [String])] = [
            (ExpenditureCategory.foodAndBeverage.rawValue, 10...150, ["lunch", "dinner", "snacks", "coffee"]),
            (ExpenditureCategory.shopping.rawValue, 100...800, ["shopping", "online", "daily goods"]),
            (ExpenditureCategory.clothing.rawValue, 200...1000, ["clothes", "shoes", "accessories"]),
            (ExpenditureCategory.daily.rawValue, 20...200, ["daily goods", "cleaning"]),
            (ExpenditureCategory.digital.rawValue, 100...3000, ["electronics", "accessories"]),
            (ExpenditureCategory.entertainment.rawValue, 30...300, ["movies", "games", "entertainment"]),
            (ExpenditureCategory.traffic.rawValue, 10...100, ["taxi", "bus", "gas"]),
            (ExpenditureCategory.medical.rawValue, 50...500, ["medicine", "clinic"]),
            (ExpenditureCategory.communication.rawValue, 20...200, ["phone bill", "data"]),
            (ExpenditureCategory.study.rawValue, 20...500, ["books", "course"]),
            (ExpenditureCategory.sport.rawValue, 30...300, ["gym", "sports gear"]),
            (ExpenditureCategory.social.rawValue, 50...500, ["party", "gifts"]),
            (ExpenditureCategory.personal.rawValue, 100...1000, ["gift", "cash"]),
            (ExpenditureCategory.travel.rawValue, 500...5000, ["tour", "flight", "hotel"])
        ]
        
        // 收入分类及金额范围
        let incomeData: [(category: String, range: ClosedRange<Double>, notes: [String])] = [
            (IncomeCategory.salary.rawValue, 5000...20000, ["monthly salary", "salary"]),
            (IncomeCategory.bonus.rawValue, 1000...5000, ["project bonus", "year-end bonus"]),
            (IncomeCategory.partTime.rawValue, 500...3000, ["freelance", "side income"]),
            (IncomeCategory.redPacket.rawValue, 10...500, ["red packet"]),
            (IncomeCategory.sideOccupation.rawValue, 1000...10000, ["side hustle"])
        ]
        
        for i in 0..<billCount {
            autoreleasepool {
                let newBill = Bill(context: context)
                newBill.id = UUID()
                
                // 80% 支出，20% 收入
                let isExpenditure = Double.random(in: 0...1) < 0.8
                
                if isExpenditure {
                    let data = expenditureData.randomElement()!
                    newBill.type = "expenditure"
                    newBill.category = data.category
                    newBill.amount = NSDecimalNumber(value: Double.random(in: data.range))
                    newBill.note = data.notes.randomElement() ?? ""
                } else {
                    let data = incomeData.randomElement()!
                    newBill.type = "income"
                    newBill.category = data.category
                    newBill.amount = NSDecimalNumber(value: Double.random(in: data.range))
                    newBill.note = data.notes.randomElement() ?? ""
                }
                
                // 随机日期（过去一年内，更集中在近期）
                let daysAgo = Int.random(in: 0...365)
                let randomDate = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
                newBill.date = randomDate
                
                newBill.createdAt = Date()
                newBill.createdBy = userId
                newBill.updatedAt = Date()
                newBill.updatedBy = userId
                
                // 每100条保存一次，避免内存累积
                if (i + 1) % 100 == 0 {
                    do {
                        try context.save()
                        print(String(format: L10n.string("mac.settings.generate_progress"), i + 1))
                    } catch {
                        print(String(format: L10n.string("mac.settings.generate_error"), error.localizedDescription))
                    }
                }
            }
        }
        
        // 最后保存剩余数据
        do {
            try context.save()
        } catch {
            print(String(format: L10n.string("mac.settings.generate_final_error"), error.localizedDescription))
        }
        
        // 在主线程显示完成提示
        DispatchQueue.main.async {
            let resultAlert = NSAlert()
            resultAlert.messageText = L10n.string("mac.settings.generate_done")
            resultAlert.informativeText = String(format: L10n.string("mac.settings.generate_success"), billCount)
            resultAlert.alertStyle = .informational
            resultAlert.runModal()
        }
    }
}
