//
//  BiometricLockManager.swift
//  iFinance
//
//  Created by WorkBuddy on 2026/4/17.
//

import Foundation
import LocalAuthentication
import Combine
import SwiftUI

// MARK: - 锁定状态

/// 生物识别应用锁的状态机
private enum BiometricLockState: String {
    /// 已解锁，用户可正常使用 App
    case unlocked
    /// 已锁定，显示遮罩等待用户验证
    case locked
}

/// 生物识别应用锁管理器
/// 负责 FaceID / TouchID 验证、锁屏状态管理
///
/// 状态机设计：
/// - 启动 / 切回前台 → requestLock() → locked（如果需要）
/// - 用户通过遮罩验证 → authenticate() 成功 → unlocked
/// - 进入后台 → markNeedsRelock() → 标记待锁定
/// - 切回前台 + 有待锁定标记 → requestLock() → locked
@MainActor
final class BiometricLockManager: ObservableObject {
    static let shared = BiometricLockManager()

    // MARK: - Published State

    /// 是否启用生物识别锁（通过 UserDefaults 持久化）
    @AppStorage("BiometricLockEnabled") var isLockEnabled: Bool = false

    /// 应用是否处于锁定状态（需要验证才能查看）
    @Published private(set) var isLocked: Bool = false

    /// 正在执行生物识别验证
    @Published private(set) var isAuthenticating: Bool = false

    /// 生物识别类型（FaceID / TouchID / None）
    private(set) var biometricType: LABiometryType = .none

    /// 设备是否支持生物识别
    var isBiometricAvailable: Bool {
        biometricType != .none
    }

    /// 当前生物识别类型的本地化名称
    var biometricDisplayName: String {
        switch biometricType {
        case .faceID: return L10n.string("lock.face_id")
        case .touchID: return L10n.string("lock.touch_id")
        default: return L10n.string("lock.biometric")
        }
    }

    /// 生物识别类型的 SF Symbol 图标
    var biometricIconName: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

    // MARK: - Private State Machine

    /// 内部状态机
    private var state: BiometricLockState = .unlocked

    /// 是否有待处理的重新锁定请求（进入后台后标记，切回前台时消费）
    private var needsRelock: Bool = false

    /// 上次成功解锁的时间戳（用于防止短时间内重复锁定）
    private var lastUnlockTime: Date?

    /// 解锁后的安全窗口期（秒），在此期间拒绝任何加锁请求
    private let unlockCooldownSeconds: TimeInterval = 5

    // MARK: - Private

    private init() {
        evaluateBiometricCapability()
    }

    // MARK: - Public API

    /// 请求锁定（幂等操作）
    ///
    /// 三层守卫确保不会重复加锁：
    /// 1. 未启用锁 → 跳过
    /// 2. 已处于锁定状态 → 跳过（幂等）
    /// 3. 在解锁冷却期内 → 跳过（防竞态）
    func requestLock() {
        // 守卫 1：未启用
        guard isLockEnabled else { return }

        // 守卫 2：已锁定（幂等）
        guard state == .unlocked else { return }

        // 守卫 3：在解锁冷却期内（防止认证弹窗导致的竞态重复加锁）
        if let lastUnlock = lastUnlockTime,
           Date().timeIntervalSince(lastUnlock) < unlockCooldownSeconds {
            return
        }

        needsRelock = false
        state = .locked
        isLocked = true
    }

    /// 标记需要在下次适当时机重新锁定（进入后台时调用）
    func markNeedsRelock() {
        needsRelock = true
    }

    /// 是否有未消费的待锁定请求（供 iFinanceApp 判断是否需要调用 requestLock）
    var shouldLockNow: Bool {
        needsRelock && isLockEnabled
    }

    /// 执行生物识别解锁
    /// - Returns: true 表示解锁成功，false 表示失败或取消
    @discardableResult
    func authenticate() async -> Bool {
        guard isBiometricAvailable else { return false }

        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedFallbackTitle = ""

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: L10n.string("lock.auth_reason")
            )
            if success {
                state = .unlocked
                isLocked = false
                lastUnlockTime = Date()
            }
            return success
        } catch {
            return false
        }
    }

    /// 启用应用锁（需先验证身份）
    @discardableResult
    func enableLock() async -> Bool {
        guard isBiometricAvailable else { return false }

        let context = LAContext()
        context.localizedFallbackTitle = ""
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: L10n.string("lock.enable_reason")
            )
            if success { isLockEnabled = true }
            return success
        } catch {
            print("[BiometricLock] Enable verification error: \(error.localizedDescription)")
            return false
        }
    }

    /// 禁用应用锁（需先验证身份，失败 2 次后降级为设备密码验证）
    /// - Returns: true 表示验证成功且已禁用，false 表示验证失败未禁用
    @discardableResult
    func disableLock() async -> Bool {
        guard isBiometricAvailable else {
            // 不支持生物识别，直接禁用
            performDisableLock()
            return true
        }

        let context = LAContext()
        context.localizedFallbackTitle = ""

        // 第 1 次尝试：生物识别
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: L10n.string("lock.disable_reason")
            )
            if success { performDisableLock() }
            return success
        } catch {
            // 生物识别失败，尝试第 2 次
            let context2 = LAContext()
            context2.localizedFallbackTitle = ""
            do {
                let success = try await context2.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: L10n.string("lock.disable_reason_retry")
                )
                if success { performDisableLock() }
                return success
            } catch {
                // 连续失败 2 次，降级为设备密码（包含 FaceID/TouchID/Passcode）
                let context3 = LAContext()
                context3.localizedFallbackTitle = ""
                do {
                    let success = try await context3.evaluatePolicy(
                        .deviceOwnerAuthentication,
                        localizedReason: L10n.string("lock.disable_reason_passcode")
                    )
                    if success { performDisableLock() }
                    return success
                } catch {
                    print("[BiometricLock] Disable verification failed: \(error.localizedDescription)")
                    return false
                }
            }
        }
    }

    /// 执行实际的禁用操作（内部方法，不做验证）
    private func performDisableLock() {
        isLockEnabled = false
        state = .unlocked
        isLocked = false
        needsRelock = false
    }

    /// 检测设备生物识别能力
    func evaluateBiometricCapability() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }
}

// MARK: - 锁屏遮罩视图

/// 全屏模糊锁屏遮罩，覆盖在 ContentView 上方
struct AppLockOverlayView: View {
    @ObservedObject var lockManager: BiometricLockManager

    var body: some View {
        ZStack {
            // 模糊背景
            VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: lockManager.biometricIconName)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white)

                Text(L10n.string("lock.title"))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                Text(L10n.string("lock.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                Button {
                    Task {
                        HapticManager.shared.medium()
                        let success = await lockManager.authenticate()
                        if success { HapticManager.shared.success() }
                    }
                } label: {
                    Text(lockManager.biometricDisplayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 200, height: 48)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(lockManager.isAuthenticating)

                if lockManager.isAuthenticating {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 1.02)))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: lockManager.isLocked)
    }
}

// MARK: - UIViewRepresentable for Blur Effect

/// UIKit blur effect wrapper for SwiftUI
private struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}
