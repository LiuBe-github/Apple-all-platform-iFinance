//
//  MaciFinanceApp.swift
//  MaciFinance
//

import SwiftUI
import CoreData

@main
struct MaciFinanceApp: App {
    let persistenceController = PersistenceController.shared

    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(
                    selectedTheme == .light ? .light :
                    selectedTheme == .dark  ? .dark : nil
                )
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 720)
    }
}
