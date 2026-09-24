//
//  HomeView.swift
//  iFinance
//
//  概况页：今日概况为主视觉，每日一言为一行小字（图片能力已移除）
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI
import UIKit
internal import CoreData

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

    // MARK: - 今日账单数据
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        predicate: NSPredicate(format: "date >= %@ AND date < %@ AND createdBy == %@",
                               Calendar.current.startOfDay(for: Date()) as NSDate,
                               Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) as NSDate,
                               PersistenceController.currentUserIdentifier),
        animation: .default
    ) private var todayBills: FetchedResults<Bill>

    // MARK: - 区间统计（本月 / 上月 / 本年）
    /// 统计窗口（视图创建时确定一次，与下方取数窗口保持一致）
    private let ranges: PeriodRanges

    /// 覆盖「本年 + 上月」的账单窗口（1 月时包含去年 12 月）
    @FetchRequest private var periodBills: FetchedResults<Bill>

    init() {
        let ranges = PeriodRanges.make()
        self.ranges = ranges
        let window = ranges.fetchWindow
        _periodBills = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
            predicate: NSPredicate(format: "date >= %@ AND date < %@ AND createdBy == %@",
                                   window.lowerBound as NSDate,
                                   window.upperBound as NSDate,
                                   PersistenceController.currentUserIdentifier),
            animation: .default
        )
    }

    /// 本月 / 上月 / 本年汇总
    private var periodSummaries: [PeriodSummary] {
        PeriodSummary.make(bills: periodBills, ranges: ranges)
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
    private var todayIncome: Decimal {
        todayBills.filter { $0.type == "income" }.reduce(Decimal(0)) { $0 + ($1.amount?.decimalValue ?? 0) }
    }

    private var todayExpense: Decimal {
        todayBills.filter { $0.type == "expenditure" }.reduce(Decimal(0)) { $0 + ($1.amount?.decimalValue ?? 0) }
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

        // 刷新按钮转一圈
        withAnimation(AppMotion.resolved(AppMotion.ambient, reduceMotion: reduceMotion)) { refreshAngle += 360 }

        // 名言淡出
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
