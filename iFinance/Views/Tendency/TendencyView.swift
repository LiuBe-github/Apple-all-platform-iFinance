//
//  TendencyView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
import Charts
internal import CoreData

struct TendencyView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // 分别为收入和支出设置时间范围选择
    @State private var selectedIncomeTimeRange = "周"
    @State private var selectedExpenseTimeRange = "周"
    
    let timeRanges = ["日", "周", "月", "6个月", "年"]
    
    private var incomeData: [ChartDataPoint] {
        fetchBills(type: "income", for: selectedIncomeTimeRange)
    }
    
    private var expenseData: [ChartDataPoint] {
        fetchBills(type: "expenditure", for: selectedExpenseTimeRange)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 收入趋势
                Section(header: Text("收入趋势").font(.headline)) {
                    Picker("", selection: $selectedIncomeTimeRange) {
                        ForEach(timeRanges, id: \.self) { range in
                            Text(range)
                                .tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if incomeData.isEmpty {
                        Text("暂无收入记录")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Chart(incomeData) { item in
                                BarMark(
                                    x: .value("时间", item.label),
                                    y: .value("金额", item.value)
                                )
                                .foregroundStyle(Color.green)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic)
                            }
                            .frame(width: calculateChartWidth(for: incomeData.count))
                        }
                        .frame(height: 200)
                    }
                }
                
                // 支出趋势
                Section(header: Text("支出趋势").font(.headline)) {
                    Picker("", selection: $selectedExpenseTimeRange) {
                        ForEach(timeRanges, id: \.self) { range in
                            Text(range)
                                .tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if expenseData.isEmpty {
                        Text("暂无支出记录")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Chart(expenseData) { item in
                                BarMark(
                                    x: .value("时间", item.label),
                                    y: .value("金额", item.value)
                                )
                                .foregroundStyle(Color.red)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic)
                            }
                            .frame(width: calculateChartWidth(for: expenseData.count))
                        }
                        .frame(height: 200)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HeaderView(isTransactionView: false)
                }
            }
            .navigationTitle("趋势")
        }
    }
    
    // MARK: - 计算图表宽度（确保可滑动）
    private func calculateChartWidth(for count: Int) -> CGFloat {
        let barWidth: CGFloat = 60
        let spacing: CGFloat = 20
        let totalWidth = CGFloat(count) * (barWidth + spacing) + 40
        return max(totalWidth, UIScreen.main.bounds.width - 32)
    }
    
    // MARK: - 数据获取
    private func fetchBills(type: String, for range: String) -> [ChartDataPoint] {
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        
        // 查询最近2年数据以提升性能
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let predicate1 = NSPredicate(format: "type == %@", type)
        let predicate2 = NSPredicate(format: "date >= %@", twoYearsAgo as NSDate)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            let bills = try viewContext.fetch(request)
            return groupByPeriod(bills, for: range)
        } catch {
            print("❌ 获取账单失败: \(error)")
            return []
        }
    }
    
    // MARK: - 聚合逻辑（按新规则实现）
    private func groupByPeriod(_ bills: [Bill], for range: String) -> [ChartDataPoint] {
        guard !bills.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        
        switch range {
        case "日":
            let intervals: [(startHour: Int, endHour: Int, label: String)] = [
                (0, 6, "0–6"),
                (6, 12, "6–12"),
                (12, 18, "12–18"),
                (18, 24, "18–24")
            ]
            
            var result: [ChartDataPoint] = []
            for interval in intervals {
                let start = calendar.date(bySettingHour: interval.startHour, minute: 0, second: 0, of: todayStart)!
                let end: Date
                if interval.endHour == 24 {
                    end = calendar.date(byAdding: .day, value: 1, to: todayStart)!
                } else {
                    end = calendar.date(bySettingHour: interval.endHour, minute: 0, second: 0, of: todayStart)!
                }
                
                let total = bills.filter { bill in
                    guard let date = bill.date else { return false }
                    return date >= start && date < end
                }.reduce(0) { sum, bill in
                    sum + (bill.amount?.doubleValue ?? 0.0)
                }
                
                result.append(ChartDataPoint(label: interval.label, value: total))
            }
            return result
            
        case "周":
            let days = (0..<7).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: todayStart)
            }.reversed()
            
            var result: [ChartDataPoint] = []
            for day in days {
                let start = day
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                
                let total = bills.filter { bill in
                    guard let date = bill.date else { return false }
                    return date >= start && date < end
                }.reduce(0) { sum, bill in
                    sum + (bill.amount?.doubleValue ?? 0.0)
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "E"
                let label = formatter.string(from: start)
                result.append(ChartDataPoint(label: label, value: total))
            }
            return result
            
        case "月":
            let days = (0..<30).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: todayStart)
            }.reversed()
            
            var result: [ChartDataPoint] = []
            for day in days {
                let start = day
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                
                let total = bills.filter { bill in
                    guard let date = bill.date else { return false }
                    return date >= start && date < end
                }.reduce(0) { sum, bill in
                    sum + (bill.amount?.doubleValue ?? 0.0)
                }
                
                let formatter = DateFormatter()
                formatter.setLocalizedDateFormatFromTemplate("M/d")
                let label = formatter.string(from: start)
                result.append(ChartDataPoint(label: label, value: total))
            }
            return result
            
        case "6个月":
            let months = (0..<6).compactMap { offset in
                calendar.date(byAdding: .month, value: -offset, to: todayStart)
            }.reversed()
            
            var result: [ChartDataPoint] = []
            for monthRef in months {
                let start = calendar.startOfDay(for: monthRef)
                guard let end = calendar.date(byAdding: .month, value: 1, to: start) else { continue }
                
                let total = bills.filter { bill in
                    guard let date = bill.date else { return false }
                    return date >= start && date < end
                }.reduce(0) { sum, bill in
                    sum + (bill.amount?.doubleValue ?? 0.0)
                }
                
                let formatter = DateFormatter()
                formatter.setLocalizedDateFormatFromTemplate("yyyy年MM月")
                let label = formatter.string(from: start)
                result.append(ChartDataPoint(label: label, value: total))
            }
            return result
            
        case "年":
            let currentYear = calendar.component(.year, from: now)
            var result: [ChartDataPoint] = []
            
            for month in 1...12 {
                var comps = DateComponents()
                comps.year = currentYear
                comps.month = month
                comps.day = 1
                guard let start = calendar.date(from: comps) else { continue }
                guard let end = calendar.date(byAdding: .month, value: 1, to: start) else { continue }
                
                let total = bills.filter { bill in
                    guard let date = bill.date else { return false }
                    return date >= start && date < end
                }.reduce(0) { sum, bill in
                    sum + (bill.amount?.doubleValue ?? 0.0)
                }
                
                let formatter = DateFormatter()
                formatter.setLocalizedDateFormatFromTemplate("MM月")
                let label = formatter.string(from: start)
                result.append(ChartDataPoint(label: label, value: total))
            }
            return result
            
        default:
            return []
        }
    }
}

// MARK: - 辅助扩展

extension Date {
    func isBefore(_ date: Date) -> Bool {
        self < date
    }
    
    func isAfter(_ date: Date) -> Bool {
        self > date
    }
}

// MARK: - 数据模型

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

// MARK: - 预览支持

#Preview {
    TendencyView()
}
