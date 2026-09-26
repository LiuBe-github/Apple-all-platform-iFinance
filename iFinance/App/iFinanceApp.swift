//
//  iFinanceApp.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/7.
//

import SwiftUI
internal import CoreData
import os

@main
struct iFinanceApp: App {
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
                            // 生物识别锁屏遮罩（仅当已启用 + 已锁定时显示）
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
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
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
                // 开屏动画：正常 1.2s，开启「减弱动态效果」时 0.6s（与首帧加载并行，不阻塞数据）
                let splashDuration: TimeInterval = reduceMotion ? 0.6 : 1.2
                DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                    withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
                }
                #if DEBUG
                let launchMs = Int((ProcessInfo.processInfo.systemUptime - Self.launchUptime) * 1000)
                Logger(subsystem: "com.liube.ifinance", category: "Launch")
                    .notice("首帧就绪：\(launchMs, privacy: .public)ms")
                #endif
                authManager.bootstrap()
                biometricLock.evaluateBiometricCapability()
                // 启动时尝试锁定（requestLock 是幂等的：未启用/已锁定/冷却期 = 空操作）
                biometricLock.requestLock()
                // 首帧之后再激活 Watch 连接（不阻塞冷启动）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    WatchSessionManager.shared.activate()
                }
                // 通知功能已暂时禁用
                // Task {
                //     _ = await NotificationManager.shared.requestAuthorization()
                // }
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
                    } else {
                        // 无需锁定（未开启应用锁 / 无待锁定标记）→ 立即解除隐私遮罩
                        biometricLock.deactivatePrivacyShield()
                    }

                case .background:
                    // 进入后台：标记待锁定，下次前台会消费此标记
                    biometricLock.markNeedsRelock()
                    // 立即开启隐私遮罩（仅在开启应用锁时生效），避免多任务快照泄露内容
                    biometricLock.activatePrivacyShield()
                    authManager.handleAppWillResignActive()

                case .inactive:
                    // 非活跃（来电、控制中心、应用切换中）同样遮挡
                    biometricLock.activatePrivacyShield()
                    authManager.handleAppWillResignActive()
                @unknown default:
                    break
                }
            }
        }
    }
}
