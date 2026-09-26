//
//  AssetView.swift
//  iFinance
//
//  资产页：总资产卡（含较上次变化）+ 按账户类型聚合的环形图 + 分类型账户列表。
//  入口：账本页右上角「资产」按钮推入，不占标签位。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改动请同步另一处。
//

import SwiftUI
import Charts
internal import CoreData

// MARK: - 金额格式化

/// 资产页统一的金额显示 / 解析（与 `CategoryPieView` 的货币格式保持一致）
enum AssetAmount {

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.locale = .autoupdatingCurrent
        return f
    }()

    /// 无货币符号的两位小数（用于无障碍摘要的 %@ 占位，符号由文案提供）
    private static let plainFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.locale = .autoupdatingCurrent
        return f
    }()

    static func string(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "¥0.00"
    }

    static func plain(_ value: Double) -> String {
        plainFormatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    /// 带正负号（用于「较上次变化」）
    static func signed(_ value: Double) -> String {
        if value > 0 { return "+" + string(value) }
        if value < 0 { return "-" + string(abs(value)) }
        return string(value)
    }

    /// 输入框文本 → 金额（容忍千分位、货币符号、全角负号与空白）
    static func parse(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "－", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// 数值 → Decimal（保留两位小数，避免二进制浮点误差写进模型）
    static func decimal(of value: Double) -> Decimal {
        Decimal(string: String(format: "%.2f", value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    /// 文本 → Decimal（保留两位小数，避免二进制浮点误差写进模型）
    static func decimal(from text: String, fallback: Decimal = 0) -> Decimal {
        guard let value = parse(text) else { return fallback }
        return decimal(of: value)
    }

    /// Decimal → 输入框文本
    static func editableText(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        return number == .zero ? "" : number.stringValue
    }
}

// MARK: - 环形图数据

/// 资产环形图的一段（按账户类型聚合）
struct AssetTypeBreakdown: Identifiable {
    let type: AssetType
    let amount: Double
    let share: Double

    var id: String { type.rawValue }
}

// MARK: - 账户分组

private struct AssetAccountGroup: Identifiable {
    let type: AssetType
    let accounts: [AssetAccount]
    let subtotal: Double

    var id: String { type.rawValue }
}

// MARK: - 资产页

struct AssetView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AssetAccount.createdAt, ascending: true)],
        predicate: PersistenceController.assetAccountUserPredicate,
        animation: .default
    ) private var accounts: FetchedResults<AssetAccount>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AssetSnapshot.date, ascending: true)],
        predicate: PersistenceController.assetSnapshotUserPredicate,
        animation: .default
    ) private var snapshots: FetchedResults<AssetSnapshot>

    /// 编辑 / 新建共用同一个 sheet；`editingAccount == nil` 表示新建
    @State private var isPresentingEditor = false
    @State private var editingAccount: AssetAccount?

    var body: some View {
        ZStack {
            AppBackgroundView()

            List {
                Section {
                    VStack(spacing: AppSpacing.lg) {
                        overviewCard
                        if !breakdown.isEmpty {
                            AssetDonutChart(data: breakdown, total: totalAssets)
                                .appCardPadding()
                                .appGlassCard()
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(
                        EdgeInsets(
                            top: AppSpacing.sm,
                            leading: AppSpacing.screen,
                            bottom: AppSpacing.sm,
                            trailing: AppSpacing.screen
                        )
                    )
                }

                if accounts.isEmpty {
                    Section {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(
                                EdgeInsets(
                                    top: AppSpacing.sm,
                                    leading: AppSpacing.screen,
                                    bottom: AppSpacing.sm,
                                    trailing: AppSpacing.screen
                                )
                            )
                    }
                } else {
                    ForEach(groupedAccounts) { group in
                        Section {
                            ForEach(group.accounts) { account in
                                accountRow(account)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            delete(account)
                                        } label: {
                                            Label("common.delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            groupHeader(group)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appContentWidth()
        }
        .navigationTitle("asset.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingAccount = nil
                    isPresentingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("asset.add")
            }
        }
        .sheet(isPresented: $isPresentingEditor, onDismiss: {
            editingAccount = nil
            persistSnapshot()
        }) {
            AssetEditSheet(account: editingAccount)
        }
    }

    // MARK: - 概览卡

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("asset.total")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(.secondary)

            Text(AssetAmount.string(totalAssets))
                .appAmountStyle(size: 34, weight: .bold)
                .foregroundStyle(.primary)
                .appNumericTransition(value: totalAssets)

            changeRow

            Divider().opacity(0.5)

            HStack(alignment: .top, spacing: AppSpacing.section) {
                statItem(titleKey: "asset.liabilities", value: AssetAmount.string(totalLiabilities), tint: negativeColor)
                statItem(titleKey: "asset.net", value: AssetAmount.string(netTotal), tint: .primary)
                Spacer(minLength: 0)
            }

            Text(String(format: L10n.string("asset.account_count"), accounts.count))
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardPadding(cozy: true)
        .appGlassCard(cornerRadius: AppRadius.sheet)
    }

    @ViewBuilder
    private var changeRow: some View {
        if let change {
            HStack(spacing: AppSpacing.sm) {
                Text("asset.change.since_last")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)

                Text(AssetAmount.signed(change.amount))
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(change.amount < 0 ? negativeColor : positiveColor)
                    .appNumericTransition(value: change.amount)

                if let ratio = change.ratio {
                    Text(AppNumberFormat.percent(abs(ratio)))
                        .font(AppTypography.tiny)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)
            }
        } else if !snapshots.isEmpty {
            Text("asset.change.first")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statItem(titleKey: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(LocalizedStringKey(titleKey))
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .appAmountStyle(size: 15, weight: .semibold)
                .foregroundStyle(tint)
        }
    }

    // MARK: - 列表

    private func groupHeader(_ group: AssetAccountGroup) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(LocalizedStringKey(group.type.localizedKey))
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: AppSpacing.sm)
            Text(AssetAmount.string(group.subtotal))
                .font(AppTypography.tiny)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func accountRow(_ account: AssetAccount) -> some View {
        let value = account.balance?.doubleValue ?? 0
        let type = AssetType(rawValue: account.type ?? "") ?? .other

        return Button {
            editingAccount = account
            isPresentingEditor = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: type.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: AppLayout.iconTile, height: AppLayout.iconTile)
                    .background(Circle().fill(AssetChartStyle.color(for: type, scheme: colorScheme)))

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text((account.name ?? "").isEmpty ? L10n.string("asset.field.name") : (account.name ?? ""))
                        .font(AppTypography.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let note = account.note, !note.isEmpty {
                        Text(note)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: AppSpacing.sm)

                Text(AssetAmount.string(value))
                    .appAmountStyle(size: 15, weight: .semibold)
                    .foregroundStyle(value < 0 ? negativeColor : Color.primary)
            }
            .frame(minHeight: AppLayout.listRowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "banknote")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("asset.empty")
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
            Text("asset.empty.hint")
                .font(AppTypography.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.section)
    }

    // MARK: - 派生数据

    private var totalAssets: Double {
        AssetBreakdown.totalAssets(accountSnapshots)
    }

    private var totalLiabilities: Double {
        AssetBreakdown.totalLiabilities(accountSnapshots)
    }

    private var netTotal: Double {
        AssetBreakdown.netTotal(accountSnapshots)
    }

    private var breakdown: [AssetTypeBreakdown] {
        AssetBreakdown.breakdown(accountSnapshots).map {
            AssetTypeBreakdown(type: $0.type, amount: $0.amount, share: $0.share)
        }
    }

    /// 最近一条快照与上一条的差值（只有一条时返回 nil，界面显示「首次记录」）
    private var change: (amount: Double, ratio: Double?)? {
        guard let current = snapshotValues.last else { return nil }
        return AssetBreakdown.change(current: current, previous: snapshotValues.dropLast().last)
    }

    private var snapshotValues: [AssetSnapshotValue] {
        snapshots.map(value(of:))
    }

    private var accountSnapshots: [AssetAccountSnapshot] {
        accounts.map(snapshot(of:))
    }

    private var groupedAccounts: [AssetAccountGroup] {
        let values = accountSnapshots
        return AssetType.displayOrder.compactMap { type in
            let items = accounts
                .filter { (AssetType(rawValue: $0.type ?? "") ?? .other) == type }
                .sorted { ($0.balance?.doubleValue ?? 0) > ($1.balance?.doubleValue ?? 0) }
            guard !items.isEmpty else { return nil }
            let subtotal = values.filter { $0.type == type }.reduce(0) { $0 + $1.balance }
            return AssetAccountGroup(type: type, accounts: items, subtotal: subtotal)
        }
    }

    private var negativeColor: Color {
        ChartSeriesStyle.accent(for: .expenditure, scheme: colorScheme)
    }

    private var positiveColor: Color {
        ChartSeriesStyle.accent(for: .income, scheme: colorScheme)
    }

    // MARK: - 实体 → 快照

    private func snapshot(of account: AssetAccount) -> AssetAccountSnapshot {
        AssetAccountSnapshot(
            id: account.id ?? UUID(),
            name: account.name ?? "",
            type: AssetType(rawValue: account.type ?? "") ?? .other,
            balance: account.balance?.doubleValue ?? 0,
            note: account.note,
            includeInTotal: account.includeInTotal,
            sortOrder: account.sortOrder
        )
    }

    private func value(of record: AssetSnapshot) -> AssetSnapshotValue {
        AssetSnapshotValue(
            date: record.date ?? Date(),
            totalAssets: record.totalAssets?.doubleValue ?? 0,
            totalLiabilities: record.totalLiabilities?.doubleValue ?? 0
        )
    }

    // MARK: - 写库

    private func delete(_ account: AssetAccount) {
        HapticManager.shared.medium()
        viewContext.delete(account)
        try? viewContext.save()
        persistSnapshot()
    }

    /// 账户变化后按当天 upsert 一条快照（每个自然日一条，同日覆盖写）
    private func persistSnapshot() {
        let context = viewContext

        let accountRequest = NSFetchRequest<AssetAccount>(entityName: "AssetAccount")
        accountRequest.predicate = PersistenceController.assetAccountUserPredicate
        guard let allAccounts = try? context.fetch(accountRequest) else { return }
        let values = allAccounts.map(snapshot(of:))

        let snapshotRequest = NSFetchRequest<AssetSnapshot>(entityName: "AssetSnapshot")
        snapshotRequest.predicate = PersistenceController.assetSnapshotUserPredicate
        snapshotRequest.sortDescriptors = [NSSortDescriptor(keyPath: \AssetSnapshot.date, ascending: true)]
        let existing = (try? context.fetch(snapshotRequest)) ?? []

        let shouldPersist = !existing.isEmpty || !allAccounts.isEmpty
        guard shouldPersist else { return }

        let totalAssets = AssetBreakdown.totalAssets(values)
        let totalLiabilities = AssetBreakdown.totalLiabilities(values)

        if let index = AssetBreakdown.upsertIndex(for: Date(), in: existing.map(value(of:))) {
            let record = existing[index]
            record.totalAssets = NSDecimalNumber(value: totalAssets)
            record.totalLiabilities = NSDecimalNumber(value: totalLiabilities)
            record.createdAt = Date()
        } else {
            let record = AssetSnapshot(context: context)
            record.id = UUID()
            record.date = Calendar.current.startOfDay(for: Date())
            record.totalAssets = NSDecimalNumber(value: totalAssets)
            record.totalLiabilities = NSDecimalNumber(value: totalLiabilities)
            record.createdAt = Date()
            record.createdBy = PersistenceController.currentUserIdentifier
        }

        try? context.save()
    }
}

// MARK: - 环形图

/// 资产类型环形图：扇区点选高亮 + 中心读数 + 明细列表（兼作图例）。
/// 交互与 `CategoryPieView` 保持一致（R11 整块绘图区可点选、R13 文本反馈、R14 形状图例）。
struct AssetDonutChart: View {

    let data: [AssetTypeBreakdown]
    let total: Double

    @State private var selectedAngle: Double?
    @State private var selectedType: AssetType?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    /// 与 `CategoryPieView` 图例色点保持一致
    private let legendDotSize: CGFloat = 10

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            donut
            breakdownList
        }
    }

    // MARK: 扇形

    private var donut: some View {
        Chart(data) { item in
            SectorMark(
                angle: .value(L10n.string("asset.total"), item.amount),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(AssetChartStyle.color(for: item.type, scheme: colorScheme))
            .cornerRadius(4)
            .opacity(selectedType == nil || selectedType == item.type ? 1 : 0.4)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("asset.title"))
        .accessibilityValue(accessibilitySummary)
        .accessibilityChartDescriptor(ChartDescriptorRepresentable { chartDescriptor })
        .onChange(of: selectedAngle) { _, newAngle in
            HapticManager.shared.selectionChanged()
            selectedType = newAngle.map { type(at: $0) } ?? nil
        }
        .chartBackground { _ in
            if let item = selectedItem {
                VStack(spacing: AppSpacing.xs) {
                    Text(LocalizedStringKey(item.type.localizedKey))
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                    Text(AssetAmount.string(item.amount))
                        .appAmountStyle(size: 15, weight: .bold)
                        .foregroundStyle(.primary)
                        .appNumericTransition(value: item.amount)
                    Text(AppNumberFormat.percent(item.share))
                        .font(AppTypography.tiny)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .transition(.opacity)
                .appAnimation(AppMotion.quick, value: item.id)
                .accessibilityHidden(true)
            }
        }
        .frame(height: AppLayout.chartHeightRegular)
        .appAnimation(AppMotion.quick, value: selectedType)
    }

    private var selectedItem: AssetTypeBreakdown? {
        guard let selectedType else { return nil }
        return data.first { $0.type == selectedType }
    }

    private func type(at angle: Double) -> AssetType? {
        guard total > 0 else { return nil }
        var cumulative: Double = 0
        for item in data {
            cumulative += item.amount
            if angle <= cumulative { return item.type }
        }
        return data.last?.type
    }

    // MARK: 明细列表

    private var breakdownList: some View {
        VStack(spacing: 1) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: AppSpacing.md) {
                    legendMark(for: index)
                        .fill(AssetChartStyle.color(for: item.type, scheme: colorScheme))
                        .frame(width: legendDotSize, height: legendDotSize)

                    Text(LocalizedStringKey(item.type.localizedKey))
                        .font(AppTypography.secondary)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: AppSpacing.sm)

                    Text(AssetAmount.string(item.amount))
                        .appAmountStyle(size: 13, weight: .semibold)
                        .foregroundStyle(.primary)

                    Text(AppNumberFormat.percent(item.share))
                        .font(AppTypography.tiny)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(selectedType == item.type ? Color.accentColor.opacity(0.10) : Color.clear)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: item))
            }

            Divider().opacity(0.5)

            HStack {
                Text("asset.total")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(AssetAmount.string(total))
                    .appAmountStyle(size: 13, weight: .bold)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    /// R14：开启「不以颜色为唯一区分手段」时按索引循环形状
    private func legendMark(for index: Int) -> AnyShape {
        differentiateWithoutColor
            ? ChartLegendShape.shape(forIndex: index).shape
            : AnyShape(Circle())
    }

    // MARK: 无障碍

    private func accessibilityLabel(for item: AssetTypeBreakdown) -> String {
        String(
            format: L10n.string("tendency.category.a11y.point"),
            L10n.string(item.type.localizedKey),
            AssetAmount.string(item.amount),
            AppNumberFormat.percent(item.share)
        )
    }

    private var accessibilitySummary: String {
        String(
            format: L10n.string("asset.a11y.summary"),
            data.count,
            AssetAmount.plain(total)
        )
    }

    private var chartDescriptor: AXChartDescriptor {
        ChartAccessibility.categoryDescriptor(
            title: L10n.string("asset.title"),
            summary: accessibilitySummary,
            slices: data.map { item in
                (name: L10n.string(item.type.localizedKey), amount: item.amount, share: item.share)
            }
        )
    }
}

// MARK: - 资产配色

/// 资产环形图配色：固定顺序取 8 色板，保证同一页内扇区与明细一一对应
enum AssetChartStyle {
    static func color(for type: AssetType, scheme: ColorScheme) -> Color {
        let index = AssetType.displayOrder.firstIndex(of: type) ?? 0
        return CategoryPalette.color(index: index, scheme: scheme)
    }
}

#Preview {
    NavigationStack {
        AssetView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
