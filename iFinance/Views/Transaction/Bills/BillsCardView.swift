//
//  BillsCard.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/12.
//

import SwiftUI
internal import CoreData

struct BillsCardView: View {
    // 使用 @FetchRequest 自动获取所有 Bill 并排序
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        animation: .default
    ) private var bills: FetchedResults<Bill>
    
    var body: some View {
        // 按日分组的账单列表
        NavigationLink(
            destination: EditBillView().toolbar(.hidden, for: .tabBar)
        ) {
            VStack {
                ForEach(groupedBills, id: \.date) { group in
                    // 日期标题和当日总支出
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(formatDateForHeader(group.date))
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            let totalAmount = calculateTotalAmount(for: group.bills)
                            Text(totalAmount < 0 ? "支出：¥\(abs(totalAmount).formatted(.number.precision(.fractionLength(2))))" : "收入：¥\(totalAmount.formatted(.number.precision(.fractionLength(2))))")
                                .font(.subheadline)
                                .foregroundColor(totalAmount < 0 ? .red : .green)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        
                        // 分隔线
                        Divider()
                            .padding(.horizontal)
                        // 当日账单列表
                        LazyVStack(spacing: 0) {
                            ForEach(group.bills.sorted { lhs, rhs in
                                // 按时间降序排列（最新的在上面）
                                (lhs.date ?? Date()) > (rhs.date ?? Date())
                            }, id: \.self) { bill in
                                TransactionRowView(bill: bill)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.background)
                        .shadow(radius: 3)
                )
            }
        }
    }
    
    func getDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M月dd日"
        return dateFormatter
    }
    
    // 按日期分组的账单数据
    private var groupedBills: [(date: Date, bills: [Bill])] {
        guard !bills.isEmpty else { return [] }
        
        // 按日期分组（忽略时间部分）
        let grouped = Dictionary(grouping: bills) { bill in
            Calendar.current.startOfDay(for: bill.date ?? Date())
        }
        
        // 按日期降序排列
        let sortedGroups = grouped.sorted {  $0.key >  $1.key }
        
        return sortedGroups.map { ( $0.key,  $0.value) }
    }
    
    // 格式化日期用于显示（例如：01/16 星期五）
    private func formatDateForHeader(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"
        let monthDay = dateFormatter.string(from: date)
        
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        let weekday = weekdayFormatter.string(from: date)
        
        // 获取中文星期几的简写
        let weekdayShort: String = {
            switch weekday {
            case "Monday": return "星期一"
            case "Tuesday": return "星期二"
            case "Wednesday": return "星期三"
            case "Thursday": return "星期四"
            case "Friday": return "星期五"
            case "Saturday": return "星期六"
            case "Sunday": return "星期日"
            default: return weekday
            }
        }()
        
        return "  \(monthDay)   \(weekdayShort)"
    }
    
    // 计算某日账单的总金额（支出为负，收入为正）
    private func calculateTotalAmount(for bills: [Bill]) -> Double {
        return bills.reduce(0) { total, bill in
            let amount = bill.amount?.doubleValue ?? 0
            // 假设支出类型为负值，收入类型为正值
            // 这里需要根据你的数据模型调整逻辑
            if let type = bill.type, type == "expenditure" {
                return total - amount
            } else {
                return total + amount
            }
        }
    }
}

#Preview {
    BillsCardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
