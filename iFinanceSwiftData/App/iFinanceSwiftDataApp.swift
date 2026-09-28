//
//  iFinanceSwiftDataApp.swift
//  iFinanceSwiftData
//
//  SwiftData 版入口（仅 iOS）：认证路由 + 生物锁遮罩 + 主题 / 语言注入。
//  与 Core Data 版不同：不注册 WCSession（不涉及 Watch 与其它平台）。
//

import SwiftUI
import SwiftData
import os

@main
struct iFinanceSwiftDataApp: App {
    /// 进程启动时间基准（DEBUG 启动耗时打点用）
    private static let launchUptime = ProcessInfo.processInfo.systemUptime

    init() {
        _ = Self.launchUptime
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var biometricLock = BiometricLockManager.shared

    /// 冷启动开屏动画（每次进程启动只展示一次）
    @State private var showSplash = true

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
                        .appPrivacyShield(biometricLock.shouldBlurForPrivacy)
                        .overlay {
                            if biometricLock.isLocked && biometricLock.isLockEnabled {
                                AppLockOverlayView(lockManager: biometricLock)
                                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                                    .zIndex(100)
                            }
                        }
                } else {
                    LoginView()
                        .appPrivacyShield(biometricLock.shouldBlurForPrivacy)
                }
            }
            .environmentObject(authManager)
            .modelContainer(persistenceController.container)
            .environment(\.locale, appLocale)
            .overlay {
                if showSplash {
                    AppSplashView()
                        .transition(.opacity)
                        .zIndex(200)
                }
            }
            .preferredColorScheme(
                selectedTheme == .light ? .light :
                    selectedTheme == .dark  ? .dark  : nil
            )
            .onAppear {
                // 让系统的本地化解析跟随 App 内语言（修正老版本遗留的不一致）
                LocalizationSync.syncIfNeeded()
                // 开屏动画：正常 1.2s，开启「减弱动态效果」时 0.6s（与首帧加载并行）
                let splashDuration: TimeInterval = reduceMotion ? 0.6 : 1.2
                DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                    withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
                }
                #if DEBUG
                let launchMs = Int((ProcessInfo.processInfo.systemUptime - Self.launchUptime) * 1000)
                Logger(subsystem: "com.liube.ifinance.swiftdata", category: "Launch")
                    .notice("首帧就绪：\(launchMs, privacy: .public)ms")
                #endif
                authManager.bootstrap()
                // 历史账单可能存着中文类型（模型旧默认值「支出」），启动时一次性改写
                persistenceController.normalizeLegacyBillTypes()
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
                    } else {
                        biometricLock.deactivatePrivacyShield()
                    }
                case .background:
                    biometricLock.markNeedsRelock()
                    biometricLock.activatePrivacyShield()
                    authManager.handleAppWillResignActive()
                case .inactive:
                    biometricLock.activatePrivacyShield()
                    authManager.handleAppWillResignActive()
                @unknown default:
                    break
                }
            }
        }
    }
}
