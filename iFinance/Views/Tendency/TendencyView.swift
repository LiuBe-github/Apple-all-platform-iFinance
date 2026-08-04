//
//  TendencyView.swift
//  iFinance
//

import SwiftUI
internal import CoreData

/// 趋势分析视图 - 显示收支趋势图表和活跃度热力图
struct TendencyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthManager
    
    // MARK: - Core Data
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: true)],
        predicate: PersistenceController.billUserPredicate,
        animation: .default
    ) private var allBills: FetchedResults<Bill>
    
    // MARK: - 视图状态
    
    @State private var showProfile = false
    
    // 支出趋势状态
    @State private var expenseSpan: SpanOption = SpanOption.all[1] // 默认周视图
    @State private var expenseChartType: ChartDisplayType = .line
    @State private var expenseSelection: Date?
    @State private var expenseScrollPosition: Date = Date().startOfDay
    
    // 收入趋势状态
    @State private var incomeSpan: SpanOption = SpanOption.all[1]
    @State private var incomeChartType: ChartDisplayType = .line
    @State private var incomeSelection: Date?
    @State private var incomeScrollPosition: Date = Date().startOfDay
    
    // 热力图数据
    @State private var dailyBillCounts: [Date: Int] = [:]
    
    // MARK: - 计算属性
    
    private var expenseSeries: [DailyAmount] {
        buildDailySeries(for: "expenditure")
    }
    
    private var incomeSeries: [DailyAmount] {
        buildDailySeries(for: "income")
    }
    
    // MARK: - 视图
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 支出趋势
                        TrendCard(
                            titleKey: "tendency.expense",
                            accent: .pink,
                            billType: "expenditure",
                            allSeries: expenseSeries,
                            allBills: allBills,
                            span: $expenseSpan,
                            chartType: $expenseChartType,
                            selectedDate: $expenseSelection,
                            scrollPosition: $expenseScrollPosition
                        )
                        
                        // 收入趋势
                        TrendCard(
                            titleKey: "tendency.income",
                            accent: .mint,
                            billType: "income",
                            allSeries: incomeSeries,
                            allBills: allBills,
                            span: $incomeSpan,
                            chartType: $incomeChartType,
                            selectedDate: $incomeSelection,
                            scrollPosition: $incomeScrollPosition
                        )
                        
                        // 活跃度热力图
                        TendencyHeatmapView(dailyBillCounts: dailyBillCounts)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
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
                if let data = authManager.avatarData, let img = UIImage(data: data) {
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
            dailyTotals[dayKey, default: 0] += bill.amount?.doubleValue ?? 0
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
