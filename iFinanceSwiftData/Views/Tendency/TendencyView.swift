//
//  TendencyView.swift
//  iFinance
//

import SwiftUI
import SwiftData

/// 趋势分析视图 - 显示收支趋势图表和活跃度热力图
struct TendencyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthManager
    
    // MARK: - 数据查询（SwiftData）
    
    @Query(filter: PersistenceController.billUserPredicate, sort: \Bill.date, animation: .default)
    private var allBills: [Bill]
    
    // MARK: - 视图状态
    
    @State private var showProfile = false
    
    // 支出趋势状态
    @State private var expenseSpan: SpanOption = SpanOption.all[1] // 默认周视图
    @State private var expenseSelection: Date?
    @State private var expenseScrollPosition: Date = Date().startOfDay
    
    // 收入趋势状态
    @State private var incomeSpan: SpanOption = SpanOption.all[1]
    @State private var incomeSelection: Date?
    @State private var incomeScrollPosition: Date = Date().startOfDay
    
    // 热力图数据
    // 分类占比跨度状态（两张饼图各自独立）
    @State private var expensePieSpan: SpanOption = SpanOption.all[1]
    @State private var incomePieSpan: SpanOption = SpanOption.all[1]

    @State private var dailyBillCounts: [Date: Int] = [:]

    // 总收支（双向柱状图）状态
    @State private var netSpan: SpanOption = SpanOption.netOptions.first ?? SpanOption.all[2]
    @State private var netSelection: Date?
    @State private var netScrollPosition: Date = Date().startOfDay
    
    // MARK: - 计算属性
    
    private var expenseSeries: [DailyAmount] {
        buildDailySeries(for: "expenditure")
    }
    
    private var incomeSeries: [DailyAmount] {
        buildDailySeries(for: "income")
    }

    /// 总收支序列（收入向上 / 支出向下），仅包含收入与支出，转账不计入
    private var netSeries: [NetTrendPoint] {
        NetTrendBuilder.series(
            entries: allBills.compactMap { bill -> (date: Date, type: String, amount: Double)? in
                guard let date = bill.date, let type = bill.type else { return nil }
                return (date: date, type: type, amount: bill.amountDouble)
            },
            spanDays: netSpan.days
        )
    }
    
    // MARK: - 视图
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        // 总收支（双向柱状图）
                        NetTrendCard(
                            points: netSeries,
                            span: $netSpan,
                            scrollPosition: $netScrollPosition,
                            selectedDate: $netSelection
                        )

                        // 支出趋势
                        TrendCard(
                            titleKey: "tendency.expense",
                            accent: .pink,
                            billType: "expenditure",
                            allSeries: expenseSeries,
                            allBills: Array(allBills),
                            span: $expenseSpan,
                            selectedDate: $expenseSelection,
                            scrollPosition: $expenseScrollPosition
                        )

                        // 支出分类占比（饼图）
                        CategoryPieCard(
                            titleKey: "tendency.expense_categories",
                            accent: .pink,
                            kind: .expenditure,
                            billType: "expenditure",
                            allBills: Array(allBills),
                            span: $expensePieSpan
                        )
                        
                        // 收入趋势
                        TrendCard(
                            titleKey: "tendency.income",
                            accent: .mint,
                            billType: "income",
                            allSeries: incomeSeries,
                            allBills: Array(allBills),
                            span: $incomeSpan,
                            selectedDate: $incomeSelection,
                            scrollPosition: $incomeScrollPosition
                        )

                        // 收入分类占比（饼图）
                        CategoryPieCard(
                            titleKey: "tendency.income_categories",
                            accent: .mint,
                            kind: .income,
                            billType: "income",
                            allBills: Array(allBills),
                            span: $incomePieSpan
                        )
                        
                        // 活跃度热力图
                        TendencyHeatmapView(dailyBillCounts: dailyBillCounts)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.section)
                    .appContentWidth()
                }
            }
            .navigationTitle("tab.tendency")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    profileButton
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .onAppear(perform: loadHeatmapData)
            .onChange(of: allBills.count) { _, _ in
                loadHeatmapData()
            }
        }
    }
    
    // MARK: - 子视图
    
    @ViewBuilder
    private var profileButton: some View {
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
    
    // MARK: - 数据处理
    
    /// 构建每日金额序列
    private func buildDailySeries(for billType: String) -> [DailyAmount] {
        let cal = Calendar.current
        let now = Date()
        let today = now.startOfDay
        // 明天开始作为结束边界（不包含），确保今天的所有数据都被包含
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? now
        guard let start = cal.date(byAdding: .day, value: -(TendencyConstants.defaultTrailingDays - 1), to: today) else {
            return []
        }
        
        // 按日期聚合金额
        var dailyTotals: [Date: Double] = [:]
        for bill in allBills {
            guard bill.type == billType,
                  let date = bill.date,
                  date >= start,
                  date < tomorrow else { continue }  // 使用 < tomorrow 而非 <= today
            let dayKey = cal.startOfDay(for: date)
            dailyTotals[dayKey, default: 0] += bill.amountDouble
        }
        
        // 生成完整日期序列（填补空白日期）
        return (0..<TendencyConstants.defaultTrailingDays).compactMap { idx in
            guard let date = cal.date(byAdding: .day, value: idx, to: start) else { return nil }
            return DailyAmount(date: date, value: dailyTotals[date, default: 0])
        }
    }
    
    /// 加载热力图数据
    private func loadHeatmapData() {
        let cal = Calendar.current
        let startDate = cal.date(byAdding: .day, value: -TendencyConstants.heatmapTrailingDays, to: Date().startOfDay) ?? Date().startOfDay
        
        var counts: [Date: Int] = [:]
        for bill in allBills {
            guard let date = bill.date else { continue }
            let day = cal.startOfDay(for: date)
            guard day >= startDate else { continue }
            counts[day, default: 0] += 1
        }
        
        dailyBillCounts = counts
    }
}

// MARK: - Preview

#Preview {
    TendencyView()
}
