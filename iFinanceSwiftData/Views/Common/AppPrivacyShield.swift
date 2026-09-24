//
//  AppPrivacyShield.swift
//  iFinanceSwiftData
//
//  进入后台时的整页隐私遮罩：高斯模糊 + 轻材质覆盖，防止应用切换器 / 多任务截图泄露账单内容。
//  是否启用由 App 入口按「用户是否开启生物识别应用锁」决定（见 BiometricLockManager.shouldBlurForPrivacy）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

struct AppPrivacyShield: ViewModifier {
    /// 是否需要遮挡（仅当用户开启应用锁且处于后台/锁定态时为 true）
    let isActive: Bool

    /// 高斯模糊半径
    var radius: CGFloat = AppLayout.privacyBlurRadius

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .blur(radius: isActive ? radius : 0)
            .overlay {
                if isActive {
                    Rectangle()
                        .fill(.regularMaterial)
                        .opacity(reduceTransparency ? 0.9 : 0.45)
                        .ignoresSafeArea()
                }
            }
            .animation(nil, value: isActive)
            .accessibilityHidden(isActive)
    }
}

extension View {
    /// 整页隐私遮罩：进入后台时对页面内容做高斯模糊（仅在开启应用锁时启用）
    func appPrivacyShield(_ isActive: Bool) -> some View {
        modifier(AppPrivacyShield(isActive: isActive))
    }
}
