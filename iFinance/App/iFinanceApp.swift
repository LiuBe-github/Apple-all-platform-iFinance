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
                            // 生物识别锁屏遮罩（仅当已启用 + 已锁定时显示）
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
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environment(\.locale, appLocale)
            .preferredColorScheme(
                selectedTheme == .light ? .light :
                    selectedTheme == .dark  ? .dark  : nil
            )
            .onAppear {
                authManager.bootstrap()
                biometricLock.evaluateBiometricCapability()
                // 启动时尝试锁定（requestLock 是幂等的：未启用/已锁定/冷却期 = 空操作）
                biometricLock.requestLock()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    authManager.handleAppDidBecomeActive()

                    // 切回前台：如果有待锁定标记，执行锁定（延迟让 UI 先渲染）
                    if biometricLock.shouldLockNow {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            biometricLock.requestLock()
                        }
                    }

                case .background:
                    // 进入后台：标记待锁定，下次前台会消费此标记
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
