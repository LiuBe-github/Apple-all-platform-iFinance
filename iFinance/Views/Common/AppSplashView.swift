//
//  AppSplashView.swift
//  iFinance
//
//  冷启动开屏动画（约 1.2s）：渐变底 + 图标呼吸光晕 + 标题 / 副标题 + 底部加载指示。
//  开启「减弱动态效果」时由调用方缩短展示时间并跳过动效。
//

import SwiftUI

struct AppSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var iconScale: CGFloat = 0.82
    @State private var iconOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.92
    @State private var glowOpacity: Double = 0.35
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 14

    var body: some View {
        ZStack {
            splashBackground

            VStack(spacing: AppSpacing.xxl) {
                logo

                VStack(spacing: AppSpacing.xs) {
                    Text("iFinance")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(L10n.string("splash.subtitle"))
                        .font(AppTypography.secondary)
                        .foregroundStyle(.secondary)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)

                ProgressView()
                    .tint(.secondary)
                    .opacity(textOpacity)
            }
            .padding(.bottom, AppSpacing.section)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("iFinance")
        .onAppear(perform: startAnimations)
    }

    // MARK: - 子视图

    private var splashBackground: some View {
        ZStack {
            Color(.systemBackground)

            RadialGradient(
                colors: [Color.blue.opacity(0.28), Color.purple.opacity(0.16), .clear],
                center: .init(x: 0.32, y: 0.28),
                startRadius: 0,
                endRadius: 420
            )

            RadialGradient(
                colors: [Color.cyan.opacity(0.22), .clear],
                center: .init(x: 0.78, y: 0.72),
                startRadius: 0,
                endRadius: 360
            )
        }
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.55), Color.purple.opacity(0.25), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 96
                    )
                )
                .frame(width: 168, height: 168)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)

            RoundedRectangle(cornerRadius: AppRadius.sheet, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: .blue.opacity(0.35), radius: 18, y: 10)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
        }
    }

    // MARK: - 动画

    private func startAnimations() {
        guard !reduceMotion else {
            iconScale = 1
            iconOpacity = 1
            textOpacity = 1
            textOffset = 0
            return
        }

        withAnimation(AppMotion.emphasized) {
            iconScale = 1
            iconOpacity = 1
        }
        withAnimation(AppMotion.emphasized.delay(0.25)) {
            textOpacity = 1
            textOffset = 0
        }
        // 呼吸光晕
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            glowScale = 1.08
            glowOpacity = 0.6
        }
    }
}

#Preview {
    AppSplashView()
}
