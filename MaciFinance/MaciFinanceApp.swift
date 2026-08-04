//
//  MaciFinanceApp.swift
//  MaciFinance
//

import SwiftUI
import CoreData

@main
struct MaciFinanceApp: App {
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
                    MainContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else {
                    LoginView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
            }
            .environmentObject(authManager)
            .environment(\.locale, appLocale)
            .preferredColorScheme(
                selectedTheme == .light ? .light :
                    selectedTheme == .dark  ? .dark  : nil
            )
            .onAppear {
                authManager.bootstrap()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    authManager.handleAppDidBecomeActive()
                case .background, .inactive:
                    authManager.handleAppWillResignActive()
                @unknown default:
                    break
                }
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 720)
    }
}
