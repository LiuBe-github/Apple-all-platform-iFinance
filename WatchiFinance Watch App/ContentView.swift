//
//  ContentView.swift
//  WatchiFinance Watch App
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataModel: WatchDataModel
    @State private var selectedTab: WatchTab = .summary
    @State private var selectedType: TransactionType = .expenditure
    @State private var selectedCategoryIndex: Int = 0
    @State private var amountText = "0"
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var sendResultMessage: String? = nil

    enum WatchTab: String, CaseIterable {
        case summary = "概览"
        case addBill = "记账"
        case history = "记录"

        var icon: String {
            switch self {
            case .summary: return "chart.pie"
            case .addBill: return "plus.circle.fill"
            case .history: return "list.bullet"
            }
        }
    }

    enum TransactionType: String, CaseIterable {
        case expenditure, income

        var title: String {
            self == .expenditure ? "支出" : "收入"
        }
    }

    // 常用分类（精简版，适合手表小屏幕）
    private static let quickExpenditureCategories: [(String, String)] = [
        ("餐饮", "fork.knife"),
        ("购物", "cart"),
        ("交通", "car"),
        ("娱乐", "gamecontroller"),
        ("日用", "bag"),
        ("其他", "ellipsis"),
    ]

    private static let quickIncomeCategories: [(String, String)] = [
        ("工资", "wallet.bifold"),
        ("奖金", "dollarsign.circle"),
        ("红包", "dollarsign.square"),
        ("其他", "ellipsis"),
    ]

    private var currentCategories: [(String, String)] {
        selectedType == .expenditure ? Self.quickExpenditureCategories : Self.quickIncomeCategories
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            summaryView
                .tabItem {
                    Image(systemName: WatchTab.summary.icon)
                    Text(WatchTab.summary.rawValue)
                }
                .tag(WatchTab.summary)

            addBillView
                .tabItem {
                    Image(systemName: WatchTab.addBill.icon)
                    Text(WatchTab.addBill.rawValue)
                }
                .tag(WatchTab.addBill)

            historyView
                .tabItem {
                    Image(systemName: WatchTab.history.icon)
                    Text(WatchTab.history.rawValue)
                }
                .tag(WatchTab.history)
        }
        .onChange(of: dataModel.todayBills.count) { _, _ in
            // 当数据更新时刷新显示
        }
    }

    // MARK: - 概览页（今日结余 + 笔数）

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 今日结余大字展示
                VStack(spacing: 4) {
                    Text("今日结余")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(dataModel.todayBalance))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(dataModel.todayBalance >= 0 ? .green : .red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

                Divider()

                // 收支摘要
                HStack(alignment: .top, spacing: 20) {
                    // 支出
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                        Text("支出")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatAmount(dataModel.todayExpense))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)

                    // 收入
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                        Text("收入")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatAmount(dataModel.todayIncome))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)

                    // 笔数
                    VStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(.blue)
                            .font(.title3)
                        Text("笔数")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(dataModel.todayCount)")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)

                if let msg = sendResultMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(msg.contains("成功") ? .green : .orange)
                        .padding(8)
                        .background(msg.contains("成功") ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }

                // 连接状态
                HStack(spacing: 4) {
                    Circle()
                        .fill(dataModel.isReachable ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(dataModel.isReachable ? "已连接 iPhone" : "未连接")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    // MARK: - 快速记账页

    private var addBillView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 类型切换（支出/收入）— watchOS 使用内联 Picker
                Picker("", selection: $selectedType) {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 120, height: 30)

                // 金额输入区域
                VStack(spacing: 8) {
                    Text("¥ \(amountText)")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity)

                    // 数字键盘（精简版，手表专用）
                    numberPadGrid
                }
                .padding(12)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)

                // 分类选择（横向滚动）
                categoryScrollView

                // 保存按钮
                Button(action: saveBill) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("保存")
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .cornerRadius(10)
                }
                .disabled(!canSave || isSaving)
            }
            .padding()
        }
    }

    // MARK: - 记录页（简单列表）

    private var historyView: some View {
        Group {
            if dataModel.todayBills.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "list.bullet.clipboard")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("今天还没有记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("点击「记账」开始记录")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding()
            } else {
                List {
                    ForEach(dataModel.todayBills.reversed()) { bill in
                        billRow(bill)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var numberPadGrid: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(keys.indices, id: \.self) { index in
                let key = keys[index]
                Button(action: {
                    handleKeyPress(key)
                }) {
                    Text(key)
                        .font(.body.weight(.medium))
                        .frame(width: 35, height: 35)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(currentCategories.indices, id: \.self) { index in
                    let cat = currentCategories[index]
                    Button(action: { selectedCategoryIndex = index }) {
                        VStack(spacing: 5) {
                            Image(systemName: cat.1)
                                .font(.title3)
                            Text(cat.0)
                                .font(.caption2)
                        }
                        .frame(width: 52, height: 56)
                        .background(selectedCategoryIndex == index ? Color.blue.opacity(0.15) : Color.clear)
                        .foregroundStyle(selectedCategoryIndex == index ? .blue : .primary)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(selectedCategoryIndex == index ? Color.blue : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func billRow(_ bill: WatchBill) -> some View {
        HStack(spacing: 8) {
            Image(systemName: categoryIconFor(bill.category))
                .font(.caption)
                .foregroundStyle(bill.type == "expenditure" ? .red : .green)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(bill.category)
                    .font(.caption)
                Text(bill.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatAmountWithSign(bill.amount, isExpense: bill.type == "expenditure"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(bill.type == "expenditure" ? .red : .green)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Logic

    private var canSave: Bool {
        guard let value = Double(amountText), value > 0 else { return false }
        return true
    }

    private func handleKeyPress(_ key: String) {
        switch key {
        case "⌫":
            if amountText.count > 1 {
                amountText.removeLast()
            } else {
                amountText = "0"
            }
        case ".":
            if !amountText.contains(".") {
                amountText += "."
            }
        default:
            if amountText == "0" {
                amountText = key
            } else {
                amountText += key
                // 限制最大长度（含小数点）
                if amountText.count > 10 {
                    amountText.removeLast()
                }
            }
        }
    }

    private func saveBill() {
        guard canSave, let value = Double(amountText), value > 0 else { return }
        isSaving = true

        let category = currentCategories[selectedCategoryIndex].0
        let type = selectedType == .expenditure ? "expenditure" : "income"

        let bill = WatchBill(amount: value, type: type, category: category)

        Task {
            let success = await dataModel.sendBill(bill)
            await MainActor.run {
                isSaving = false
                if success {
                    sendResultMessage = "✅ 已同步到 iPhone"
                } else {
                    sendResultMessage = "⚠️ 已缓存，稍后自动同步"
                }

                // 重置表单
                amountText = "0"
                selectedCategoryIndex = 0

                // 3 秒后清除提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    sendResultMessage = nil
                }
            }
        }
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: abs(value))) ?? "¥\(abs(value))"
    }

    private func formatAmountWithSign(_ value: Double, isExpense: Bool) -> String {
        let prefix = isExpense ? "-" : "+"
        return "\(prefix)\(formatAmount(value))"
    }

    private func categoryIconFor(_ categoryName: String) -> String {
        for (name, icon) in Self.quickExpenditureCategories where name == categoryName { return icon }
        for (name, icon) in Self.quickIncomeCategories where name == categoryName { return icon }
        return "questionmark"
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchDataModel.shared)
}
