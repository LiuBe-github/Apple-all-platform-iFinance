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
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue
    @StateObject private var authManager = AuthManager.shared

    let persistenceController = PersistenceController.shared

    private var appLocale: Locale {
        let language = AppLanguage(rawValue: appLanguage) ?? .system
        switch language {
        case .system:
            return .autoupdatingCurrent
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .zhHant:
            return Locale(identifier: "zh-Hant")
        case .en:
            return Locale(identifier: "en")
        case .ja:
            return Locale(identifier: "ja")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environment(\.locale, appLocale)
            .preferredColorScheme(
                selectedTheme == .light ? .light :
                    selectedTheme == .dark  ? .dark  : nil
            )
            .onAppear {
                authManager.bootstrap()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    authManager.handleAppDidBecomeActive()
                case .inactive, .background:
                    authManager.handleAppWillResignActive()
                @unknown default:
                    break
                }
            }
        }
    }
}
