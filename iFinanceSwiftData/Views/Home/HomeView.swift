//
//  HomeView.swift
//  iFinanceSwiftData
//
//  概况页：今日概况为主视觉，每日一言为一行小字（图片能力已移除）
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI
import UIKit
import SwiftData

// MARK: - 分享数据载体
private struct SharePayload: Identifiable {
    let id = UUID()
    let imageURL: URL
}

// MARK: - 主视图
struct HomeView: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var authManager: AuthManager
    @State private var showProfile = false

    // MARK: - 今日账单数据（SwiftData）
    @Query(filter: PersistenceController.billUserPredicate, sort: \Bill.date, order: .reverse, animation: .default)
    private var userBills: [Bill]

    /// 今日账单（先按用户查询，再在内存中过滤当天）
    private var todayBills: [Bill] {
        let calendar = Calendar.current
        return userBills.filter { bill in
            guard let date = bill.date else { return false }
            return calendar.isDate(date, inSameDayAs: Date())
        }
    }

    // MARK: - 区间统计（本月 / 上月 / 本年）
    /// 统计窗口（视图创建时确定一次）
    private let ranges = PeriodRanges.make()

    /// 本月 / 上月 / 本年汇总
    /// SwiftData 版与今日卡一致：在已按用户过滤的结果上做内存过滤，避免额外的谓词翻译差异。
    private var periodSummaries: [PeriodSummary] {
        let window = ranges.fetchWindow
        let windowBills = userBills.filter { bill in
            guard let date = bill.date else { return false }
            return window.contains(date)
        }
        return PeriodSummary.make(bills: windowBills, ranges: ranges)
    }

    // MARK: - UI State
    @State private var sentences: [DailySentence] = []
    @State private var currentSentence: DailySentence?
    @State private var isInitialLoading = true
    @State private var isRefreshing = false
    @State private var quoteOpacity: Double = 1
    @State private var refreshAngle: Double = 0
    @State private var shareBounceTrigger = 0
    @State private var contentVisible = false

    // 分享相关
    @State private var sharePayload: SharePayload?
    @State private var sharedTempURL: URL?
    @State private var shareError: String?

    // MARK: - 当日统计计算属性
    // 类型一律走 `BillMath`：兼容历史中文类型（「支出」等），转账不计入
    private var todayIncome: Decimal {
        todayBills.filter { BillMath.isIncome($0.type) }.reduce(Decimal(0)) { $0 + ($1.amount ?? 0) }
    }

    private var todayExpense: Decimal {
        todayBills.filter { BillMath.isExpenditure($0.type) }.reduce(Decimal(0)) { $0 + ($1.amount ?? 0) }
    }

    private var todayBalance: Decimal {
        todayIncome - todayExpense
    }

    private var todayDateText: String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if isInitialLoading {
                            Spacer(minLength: 120)
                            ProgressView().scaleEffect(1.3)
                            Spacer(minLength: 200)
                        } else {
                            Spacer(minLength: AppSpacing.section)

                            // ── 今日概况（主视觉） ──
                            TodayBalanceCard(
                                income: todayIncome,
                                expense: todayExpense,
                                balance: todayBalance,
                                billCount: todayBills.count
                            )
                            .padding(.horizontal, AppSpacing.screen)
                            .transition(AppMotion.resolvedTransition(AppMotion.riseIn, reduceMotion: reduceMotion))

                            Spacer(minLength: AppSpacing.lg)

                            // ── 周期概况（本月 / 上月 / 本年） ──
                            PeriodSummaryCard(periods: periodSummaries)
                                .padding(.horizontal, AppSpacing.screen)
                                .transition(AppMotion.resolvedTransition(AppMotion.riseIn, reduceMotion: reduceMotion))

                            if let s = currentSentence {
                                Spacer(minLength: AppSpacing.lg)

                                // ── 每日一言卡 ──
                                SentenceCardView(sentence: s) {
                                    guard !isRefreshing else { return }
                                    HapticManager.shared.medium()
                                    refresh()
                                }
                                .id(s.id)
                                .padding(.horizontal, AppSpacing.screen)
                                .opacity(quoteOpacity)
                            }

                            Spacer(minLength: AppSpacing.section)

                            // ── 分享按钮 ──
                            Button {
                                HapticManager.shared.light()
                                shareBounceTrigger += 1
                                renderAndShare()
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(width: 50, height: 50)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.8))
                                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                                    .symbolEffect(.bounce, value: shareBounceTrigger)
                            }
                            .foregroundStyle(.primary)
                            .buttonStyle(ScaleButtonStyle())
                            .padding(.bottom, AppSpacing.xl)
                        }
                    }
                    .appContentWidth()
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Group {
                            if let img = AvatarImageCache.shared.image(for: authManager.avatarData) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.title.bold())
                            }
                        }
                        .foregroundColor(.blue)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("header.edit_profile")
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(item: $sharePayload, onDismiss: {
                if let url = sharedTempURL {
                    try? FileManager.default.removeItem(at: url)
                }
                sharedTempURL = nil
            }) { payload in
                ShareSheet(items: [payload.imageURL])
                    .presentationDetents([.medium, .large])
            }
            .alert(L10n.string("home.share_failed"), isPresented: Binding(
                get: { shareError != nil },
                set: { if !$0 { shareError = nil } }
            )) {
                Button(L10n.string("common.ok")) { shareError = nil }
            } message: {
                Text(shareError ?? "")
            }
            .navigationTitle("home.title")
            .onAppear {
                loadSentences()
            }
        }
    }

    // MARK: - 加载 JSON
    private func loadSentences() {
        guard let url = Bundle.main.url(forResource: "EconomicQuotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([DailySentence].self, from: data)
        else {
            isInitialLoading = false
            return
        }
        sentences = list
        currentSentence = list.randomElement()
        isInitialLoading = false

        // 首次加载完成后的入场动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(AppMotion.resolved(AppMotion.emphasized, reduceMotion: reduceMotion)) {
                contentVisible = true
            }
        }
    }

    // MARK: - 换一句（仅更换名言，不再加载图片）
    private func refresh() {
        guard sentences.count > 1 else { return }
        isRefreshing = true

        withAnimation(AppMotion.resolved(AppMotion.ambient, reduceMotion: reduceMotion)) { refreshAngle += 360 }

        withAnimation(AppMotion.resolved(AppMotion.quick, reduceMotion: reduceMotion)) {
            quoteOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let filtered = sentences.filter { $0.id != currentSentence?.id }
            currentSentence = (filtered.isEmpty ? sentences : filtered).randomElement()

            withAnimation(AppMotion.resolved(AppMotion.emphasized, reduceMotion: reduceMotion)) {
                quoteOpacity = 1
            }
            isRefreshing = false
        }
    }

    // MARK: - 渲染分享卡片（含当日统计数据，无图片）
    @MainActor
    private func renderAndShare() {
        guard let sentence = currentSentence else { return }

        let cardWidth: CGFloat = 375
        let cardHeight: CGFloat = 560

        let renderer = ImageRenderer(
            content: ShareCardView(
                sentence: sentence,
                periods: periodSummaries,
                dailyBalance: todayBalance,
                incomeTotal: todayIncome,
                expenseTotal: todayExpense,
                billCount: todayBills.count,
                dateText: todayDateText
            )
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sheet, style: .continuous))
        )
        renderer.scale = displayScale

        guard let image = renderer.uiImage else {
            shareError = L10n.string("home.share_error_render")
            return
        }

        guard let data = image.jpegData(compressionQuality: 0.92) else {
            shareError = L10n.string("home.share_error_encode")
            return
        }

        let fileName = "iFinance-\(todayDateText)-\(UUID().uuidString.prefix(6)).jpg"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            sharedTempURL = fileURL
            sharePayload = SharePayload(imageURL: fileURL)
        } catch {
            shareError = String(format: L10n.string("home.share_error_write"), error.localizedDescription)
        }
    }
}

#Preview {
    HomeView()
}
