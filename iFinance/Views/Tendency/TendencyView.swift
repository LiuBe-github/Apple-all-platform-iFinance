//
//  TendencyView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
import Charts

struct TransactionData: Identifiable {
    let id = UUID()
    let week: String
    let value: Double
}

struct TendencyView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedTimeRange = "周"
    let timeRange = ["日", "周", "月", "6个月", "年"]
    let data = [
        TransactionData(week: "周一", value: 30),
        TransactionData(week: "周二", value: 35),
        TransactionData(week: "周三", value: 20),
        TransactionData(week: "周四", value: 10),
        TransactionData(week: "周五", value: 50),
        TransactionData(week: "周六", value: 53),
        TransactionData(week: "周日", value: 25.5)
    ]
    
    var body: some View {
        NavigationSplitView {
            List {
                VStack(alignment: .leading, spacing: 0) {
                    Picker("", selection: $selectedTimeRange) {
                        ForEach(timeRange, id: \.self) { range in
                            Text(range)
                                .tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    Text("平均")
                        .foregroundStyle(.gray)
                    Text("31.93元/天")
                        .font(.title)
                    Text("2026年1月2日至8日")
                        .foregroundStyle(.gray)
                    Chart(data) { item in
                        LineMark(
                            x: .value("Week", item.week),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(.red)
                        .symbol(Circle())
                    }
                    .chartXAxis {
                        AxisMarks(values: data.map{$0.week})
                    }
                    .frame(height: 200)
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                   HeaderView(isTransactionView: false)
                }
            }
            .navigationTitle("消费趋势")
        } detail: {
            Text("Select a Item")
        }
    }
}

#Preview {
    TendencyView()
}
