//
//  BillListView.swift
//  MaciFinance
//

import SwiftUI
import CoreData

struct BillListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var searchText = ""
    @State private var selectedType: FilterType = .all

    enum FilterType: String, CaseIterable, Identifiable {
        case all, expense, income, transfer
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "全部"
            case .expense: return "支出"
            case .income: return "收入"
            case .transfer: return "转账"
            }
        }
    }

    // MARK: - FetchRequest

    @FetchRequest private var bills: FetchedResults<Bill>

    init() {
        _bills = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)]
        )
    }

    private var filteredBills: [Bill] {
        var result = Array(bills)

        if selectedType != .all {
            switch selectedType {
            case .expense:
                result = result.filter { $0.type == "expenditure" }
            case .income:
                result = result.filter { $0.type == "income" }
            case .transfer:
                result = result.filter { $0.type == "transfer" }
            default: break
            }
        }

        if !searchText.isEmpty {
            result = result.filter {
                ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return result
    }

    // Grouped by date
    private var groupedBills: [(String, [Bill])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredBills) { bill -> String in
            guard let date = bill.date else { return "" }
            let today = Date()
            if cal.isDateInToday(date) { return "今天" }
            if cal.isDateInYesterday(date) { return "昨天" }

            let daysAgo = cal.dateComponents([.day], from: startOfDay(date), to: startOfDay(today)).day ?? 0
            if daysAgo < 7 { return "最近" }

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy年M月"
            return fmt.string(from: date)
        }
        return grouped.sorted { $0.key > $1.key } // newest first
    }

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    // MARK: - Totals

    private var totalExpense: Double {
        filteredBills.filter { $0.type == "expenditure" }.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }
    private var totalIncome: Double {
        filteredBills.filter { $0.type == "income" }.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar area (只读，无新增按钮)
            HStack(spacing: 12) {
                TextField("搜索账单...", text: $searchText, prompt: Text("搜索分类或备注"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)

                Picker("类型", selection: $selectedType) {
                    ForEach(FilterType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Summary bar
            HStack(spacing: 32) {
                StatLabel(title: "收入", value: totalIncome, color: .green)
                StatLabel(title: "支出", value: totalExpense, color: .red)
                Divider().frame(height: 24)
                Text("共 \(filteredBills.count) 笔")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)

            Divider()

            // List content (纯只读展示)
            if groupedBills.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("暂无账单数据")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("请在 iPhone 或 Apple Watch 上记账")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedBills.indices, id: \.self) { index in
                            Section {
                                ForEach(groupedBills[index].1) { bill in
                                    BillDetailRow(bill: bill)
                                }
                            } header: {
                                SectionHeader(
                                    title: groupedBills[index].0,
                                    bills: groupedBills[index].1,
                                    isSticky: index == 0
                                )
                                .background(Color(nsColor: .windowBackgroundColor))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct StatLabel: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(formatCurrency(value)).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(color)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let bills: [Bill]
    var isSticky: Bool = false

    private var dayTotal: Double {
        bills.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }

    var body: some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .bold))
            Spacer()
            Text("\(bills.count) 笔").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct BillDetailRow: View {
    let bill: Bill

    private var isExpense: Bool {
        bill.type == "expenditure" || bill.type == "transfer"
    }

    private var amountText: String {
        let prefix = isExpense ? "-" : "+"
        return "\(prefix)\(formatCurrency(bill.amount?.doubleValue ?? 0))"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isExpense ? Color.red.opacity(0.08) : Color.green.opacity(0.08))
                    .frame(width: 40, height: 40)

                Image(systemName: categoryIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isExpense ? .red : .green)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(bill.category ?? "未分类")
                    .font(.system(size: 14, weight: .medium))

                if let note = bill.note, !note.isEmpty, note != "无备注" {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(amountText)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isExpense ? .red : .green)

                Text(bill.date.map { formatShortDate($0) } ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    private var categoryIcon: String {
        guard let cat = bill.category else { return "questionmark" }
        if isExpense {
            return ExpenditureCategory.allCases.first(where: { $0.rawValue == cat })?.icon ?? "tag.fill"
        }
        return IncomeCategory.allCases.first(where: { $0.rawValue == cat })?.icon ?? "tag.fill"
    }
}

private func formatShortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    if !Calendar.current.isDateInToday(date) {
        f.dateFormat = "M/d HH:mm"
    }
    return f.string(from: date)
}
