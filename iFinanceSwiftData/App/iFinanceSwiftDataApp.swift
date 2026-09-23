//
//  iFinanceSwiftDataApp.swift
//  iFinanceSwiftData
//
//  SwiftData 版入口（仅 iOS）：认证路由 + 生物锁遮罩 + 主题 / 语言注入。
//  与 Core Data 版不同：不注册 WCSession（不涉及 Watch 与其它平台）。
//

import SwiftUI
import SwiftData

@main
struct iFinanceSwiftDataApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var biometricLock = BiometricLockManager.shared

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
                        .overlay {
                            if biometricLock.isLocked && biometricLock.isLockEnabled {
                                AppLockOverlayView(lockManager: biometricLock)
                                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                                    .zIndex(100)
                            }
                        }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .modelContainer(persistenceController.container)
            .environment(\.locale, appLocale)
            .preferredColorScheme(
                selectedTheme == .light ? .light :
                    selectedTheme == .dark  ? .dark  : nil
            )
            .onAppear {
                authManager.bootstrap()
                biometricLock.evaluateBiometricCapability()
                biometricLock.requestLock()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    authManager.handleAppDidBecomeActive()
                    if biometricLock.shouldLockNow {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            biometricLock.requestLock()
                        }
                    }
                case .background:
                    biometricLock.markNeedsRelock()
                    fallthrough
                case .inactive:
                    authManager.handleAppWillResignActive()
                @unknown default:
                    break
                }
            }
        }
    }
}
