//
//  iFinanceApp.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/7.
//

import SwiftUI
internal import CoreData

@main
struct iFinanceApp: App {
    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system
    
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(
                    selectedTheme == .light ? .light :
                        selectedTheme == .dark  ? .dark  : nil
                )
        }
    }
}
