//
//  TransactionView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
import SwiftData

struct TransactionView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showingAddBillView = false
    @State private var showProfile = false
    @State private var showAsset = false
    @State private var showingSearch = false
    @State private var selectedCategory: String? = nil
    @State private var selectedNote: String? = nil
    @State private var budgetCardRefreshId = 0  // 用于刷新预算卡片

    // 用于检查是否有账单（SwiftData：按当前用户查询）
    @Query(filter: PersistenceController.billUserPredicate, sort: \Bill.date, order: .reverse, animation: .default)
    private var bills: [Bill]

    // MARK: - 账单内容指纹（用于刷新预算卡）

    /// 只比数量会漏掉「编辑金额」这类改动，所以把金额 / 类型 / 分类 / 日期一起纳入指纹。
    private var billRevision: Int {
        var hasher = Hasher()
        for bill in bills {
            hasher.combine(bill.id)
            hasher.combine(bill.amountDouble)
            hasher.combine(bill.type)
            hasher.combine(bill.category)
            hasher.combine(bill.date)
        }
        return hasher.finalize()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(.vertical) {
                    // 预算卡片（通过id刷新）
                    BudgetCardView()
                        .id(budgetCardRefreshId)
                        .padding(.horizontal)
                        .padding(.bottom)

                    // 根据账单数量决定显示什么
                    if !bills.isEmpty {
                        // 有账单时显示 BillsCardView（支持类别+备注双过滤）
                        BillsCardView(selectedCategory: $selectedCategory, selectedNote: $selectedNote)
                            .padding(.horizontal)
                            .padding(.bottom)
                    } else {
                        // 没有账单时显示提示
                        VStack(spacing: AppSpacing.md) {
                            Spacer()
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(.blue.opacity(0.8))
                                .symbolEffect(.pulse, options: .repeating)
                            Text("transaction.empty")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxHeight: 400)
                        .padding(.horizontal)
                        .appGlassCard(cornerRadius: AppRadius.sheet)
                    }
                }
                .appContentWidth()
                .refreshable {
                    // 短暂延迟让用户看到加载指示器
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    // 刷新预算卡片（改变 id 强制重新创建视图和 FetchRequest）
                    budgetCardRefreshId += 1
                }
                .onChange(of: billRevision) { _, _ in
                    // 新增 / 编辑（含改金额）/ 删除账单后，强制重建预算卡
                    budgetCardRefreshId += 1
                }
            }
            .navigationTitle("transaction.title")
            .scrollIndicators(.automatic)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAddBillView = true
                    } label: {
                        Text("header.add_bill")
                            .font(.title.bold())
                            .foregroundStyle(.blue)
                            .buttonStyle(.plain)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // 搜索按钮（选中类别或备注时蓝色高亮）
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .foregroundStyle(
                                (selectedCategory != nil || selectedNote != nil)
                                ? .blue
                                : .primary
                            )
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("search.title")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // 资产按钮（入口不占标签位）
                    Button {
                        showAsset = true
                    } label: {
                        Image(systemName: "banknote")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("asset.title")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // 个人中心按钮
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
            .navigationDestination(isPresented: $showAsset) {
                AssetView()
            }
            .sheet(isPresented: $showingAddBillView) {
                AddBillView()
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingSearch) {
                SearchSheet(
                    selectedCategory: $selectedCategory,
                    selectedNote: $selectedNote,
                    isPresented: $showingSearch,
                    bills: bills
                )
            }
        }
    }
}

// MARK: - 搜索弹窗（全屏展开，支持类别+备注搜索+搜索历史）
struct SearchSheet: View {
    @Binding var selectedCategory: String?
    @Binding var selectedNote: String?
    @Binding var isPresented: Bool
    let bills: [Bill]

    @State private var searchText = ""
    @State private var historyKeywords: [String] = []
    @AppStorage("SearchHistory") private var historyData: Data = Data()

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(historyKeywords) {
            historyData = data
        }
    }

    private func addToHistory(_ keyword: String) {
        guard !keyword.isEmpty else { return }
        historyKeywords.removeAll { $0 == keyword }
        historyKeywords.insert(keyword, at: 0)
        if historyKeywords.count > 10 {
            historyKeywords = Array(historyKeywords.prefix(10))
        }
        saveHistory()
    }

    private func removeFromHistory(_ keyword: String) {
        historyKeywords.removeAll { $0 == keyword }
        saveHistory()
    }

    private func clearHistory() {
        historyKeywords = []
        saveHistory()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                searchBar
                    .padding(.top, AppSpacing.sm)

                Divider()
                    .padding(.top, AppSpacing.sm)

                // 结果列表
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // 搜索历史（搜索框为空时显示）
                        if searchText.isEmpty && !historyKeywords.isEmpty {
                            historySection
                        }

                        // 匹配备注的账单
                        if !searchText.isEmpty && !matchingBills.isEmpty {
                            SectionHeader(
                                title: L10n.string("search.bill_matches"),
                                systemImage: "doc.text",
                                color: .orange
                            )
                            ForEach(matchingBills.prefix(10), id: \.persistentModelID) { bill in
                                BillNoteRow(bill: bill) {
                                    if let note = bill.note { addToHistory(note) }
                                    selectedNote = bill.note
                                    selectedCategory = nil
                                    isPresented = false
                                }
                            }
                        }

                        // 支出类别
                        if !filteredExpenditureCategories.isEmpty {
                            SectionHeader(
                                title: L10n.string("bill.type_expenditure"),
                                systemImage: "arrow.up.circle.fill",
                                color: .red
                            )
                            ForEach(filteredExpenditureCategories, id: \.self) { category in
                                CategoryRow(
                                    category: category,
                                    isSelected: selectedCategory == category.rawValue,
                                    onSelect: {
                                        addToHistory(category.localizedDisplayName)
                                        selectedCategory = category.rawValue
                                        selectedNote = nil
                                        isPresented = false
                                    }
                                )
                            }
                        }

                        // 收入类别
                        if !filteredIncomeCategories.isEmpty {
                            SectionHeader(
                                title: L10n.string("bill.type_income"),
                                systemImage: "arrow.down.circle.fill",
                                color: .green
                            )
                            ForEach(filteredIncomeCategories, id: \.self) { category in
                                CategoryRow(
                                    category: category,
                                    isSelected: selectedCategory == category.rawValue,
                                    onSelect: {
                                        addToHistory(category.localizedDisplayName)
                                        selectedCategory = category.rawValue
                                        selectedNote = nil
                                        isPresented = false
                                    }
                                )
                            }
                        }

                        // 无结果
                        if searchText.isEmpty && historyKeywords.isEmpty {
                            ContentUnavailableView(
                                L10n.string("search.no_result"),
                                systemImage: "magnifyingglass",
                                description: Text(L10n.string("search.no_result.desc"))
                            )
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationTitle(L10n.string("search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                historyKeywords = (try? JSONDecoder().decode([String].self, from: historyData)) ?? []
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // 取消搜索（清除当前筛选）
                    if selectedCategory != nil || selectedNote != nil {
                        Button(L10n.string("search.cancel_filter")) {
                            selectedCategory = nil
                            selectedNote = nil
                            isPresented = false
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("common.done")) {
                        isPresented = false
                    }
                }
            }
        }
    }

    // MARK: - 搜索历史区块
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionHeader(
                    title: L10n.string("search.history"),
                    systemImage: "clock",
                    color: .blue
                )
                Spacer()
                Button(L10n.string("search.clear_history")) {
                    clearHistory()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(historyKeywords, id: \.self) { keyword in
                HStack(spacing: AppSpacing.sm) {
                    Button {
                        searchText = keyword
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(keyword)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.md)
                        .padding(.leading, AppSpacing.xs)
                    }
                    .buttonStyle(.plain)

                    Button {
                        removeFromHistory(keyword)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: - 搜索框
    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L10n.string("search.placeholder"), text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        .padding(.horizontal)
        .padding(.bottom, AppSpacing.xs)
    }

    // MARK: - 过滤后的支出类别
    private var filteredExpenditureCategories: [ExpenditureCategory] {
        ExpenditureCategory.allCases.filter {
            $0.localizedDisplayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - 过滤后的收入类别
    private var filteredIncomeCategories: [IncomeCategory] {
        IncomeCategory.allCases.filter {
            $0.localizedDisplayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - 匹配备注的账单
    private var matchingBills: [Bill] {
        guard !searchText.isEmpty else { return [] }
        return bills.filter { bill in
            guard let note = bill.note, !note.isEmpty else { return false }
            return note.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - 账单备注行
private struct BillNoteRow: View {
    let bill: Bill
    let onSelect: () -> Void

    private var formattedAmount: String {
        let amt = bill.amountDouble
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: NSNumber(value: amt)) ?? "¥\(amt)"
    }

    private var typeColor: Color {
        BillMath.isExpenditure(bill.type) ? .red : .green
    }

    private var typeLabel: String {
        BillMath.isExpenditure(bill.type)
            ? L10n.string("bill.type_expenditure")
            : L10n.string("bill.type_income")
    }

    private var categoryLabel: String {
        bill.category ?? "—"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppSpacing.md) {
                // 金额
                Text(formattedAmount)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(typeColor)
                    .frame(width: 80, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.note ?? "—")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: AppSpacing.xs) {
                        Text(categoryLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(typeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 分类行（泛型，规避 any TransactionCategory 无法访问具体类型属性的问题）
private struct CategoryRow<Category: TransactionCategory>: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .white : .blue)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    )

                Text(category.localizedDisplayName)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section 头部
private struct SectionHeader: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }
}

#Preview {
    TransactionView()
        .environment(\.modelContext, PersistenceController.preview.container.viewContext)
}
