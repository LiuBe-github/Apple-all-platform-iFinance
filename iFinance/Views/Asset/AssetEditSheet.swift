//
//  AssetEditSheet.swift
//  iFinance
//
//  资产账户编辑 sheet：名称 / 类型 / 余额（支持负数 = 负债）/ 备注 / 是否计入总资产。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改动请同步另一处。
//

import SwiftUI
internal import CoreData

struct AssetEditSheet: View {

    /// 编辑已有账户；传 nil 表示新建
    let account: AssetAccount?

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var name: String = ""
    @State private var type: AssetType = .cash
    @State private var amountText: String = ""
    @State private var isNegative: Bool = false
    @State private var note: String = ""
    @State private var includeInTotal: Bool = true
    @State private var errorMessage: String?
    @State private var isConfirmingDelete = false

    private var isEditing: Bool { account != nil }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 余额（带符号）
    private var balanceValue: Double {
        let magnitude = abs(AssetAmount.parse(amountText) ?? 0)
        return isNegative ? -magnitude : magnitude
    }

    private var negativeColor: Color {
        ChartSeriesStyle.accent(for: .expenditure, scheme: colorScheme)
    }

    private var positiveColor: Color {
        ChartSeriesStyle.accent(for: .income, scheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        nameSection
                        typeSection
                        balanceSection
                        noteSection
                        includeSection
                        if isEditing { deleteSection }
                    }
                    .padding(AppSpacing.lg)
                    .appContentWidth(AppLayout.formMaxWidth)
                }
            }
            .navigationTitle(L10n.string(isEditing ? "asset.edit" : "asset.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .alert(
                errorMessage ?? "",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    // MARK: - 名称

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("asset.field.name")
            TextField(L10n.string("asset.field.name_placeholder"), text: $name)
                .textFieldStyle(.plain)
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
        }
    }

    // MARK: - 类型

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("asset.field.type")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 3),
                spacing: AppSpacing.md
            ) {
                ForEach(AssetType.displayOrder, id: \.self) { item in
                    typeTile(item)
                }
            }
        }
    }

    private func typeTile(_ item: AssetType) -> some View {
        let isSelected = type == item
        let tint = AssetChartStyle.color(for: item, scheme: colorScheme)

        return Button {
            type = item
            HapticManager.shared.light()
        } label: {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: item.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Color.primary)
                    .frame(width: AppLayout.iconTile, height: AppLayout.iconTile)
                    .background(Circle().fill(isSelected ? tint : Color(UIColor.tertiarySystemFill)))

                Text(LocalizedStringKey(item.localizedKey))
                    .font(AppTypography.tiny)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.12) : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                    .strokeBorder(isSelected ? tint : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - 余额

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("asset.field.balance")

            HStack(spacing: AppSpacing.sm) {
                // 数字键盘没有负号，用 ± 按钮切换（负数 = 负债）
                Button {
                    isNegative.toggle()
                    HapticManager.shared.light()
                } label: {
                    Text(isNegative ? "−" : "+")
                        .font(AppTypography.amount(20, weight: .bold))
                        .foregroundStyle(isNegative ? negativeColor : positiveColor)
                        .frame(width: AppLayout.iconTile, height: AppLayout.iconTile)
                        .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("asset.field.balance")

                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .appAmountStyle(size: 20, weight: .semibold)
                    .foregroundStyle(isNegative ? negativeColor : Color.primary)
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
            }
        }
    }

    // MARK: - 备注

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("asset.field.note")
            TextField(L10n.string("asset.field.note_placeholder"), text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
        }
    }

    // MARK: - 计入总资产

    private var includeSection: some View {
        Toggle(isOn: $includeInTotal) {
            Text("asset.field.include_in_total")
                .font(AppTypography.body)
                .foregroundStyle(.primary)
        }
        .tint(positiveColor)
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    // MARK: - 删除

    private var deleteSection: some View {
        Button {
            isConfirmingDelete = true
        } label: {
            Text("common.delete")
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(negativeColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AppLayout.listRowMinHeight)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                        .fill(negativeColor.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
        .alert("common.delete", isPresented: $isConfirmingDelete) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive) { deleteAccount() }
        } message: {
            Text("asset.delete_confirm")
        }
    }

    // MARK: - 辅助

    private func sectionTitle(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func loadIfEditing() {
        guard let account else { return }
        name = account.name ?? ""
        type = AssetType(rawValue: account.type ?? "") ?? .other
        let value = account.balance?.doubleValue ?? 0
        isNegative = value < 0
        amountText = value == 0 ? "" : AssetAmount.plain(abs(value))
        note = account.note ?? ""
        includeInTotal = account.includeInTotal
    }

    private func save() {
        guard !trimmedName.isEmpty else {
            HapticManager.shared.warning()
            errorMessage = L10n.string("asset.error.name_empty")
            return
        }

        let identifier = PersistenceController.currentUserIdentifier
        let balance = AssetAmount.decimal(of: balanceValue)
        let noteValue = trimmedNote.isEmpty ? nil : trimmedNote

        if let account {
            account.name = trimmedName
            account.type = type.rawValue
            account.balance = NSDecimalNumber(decimal: balance)
            account.note = noteValue
            account.includeInTotal = includeInTotal
            account.updatedAt = Date()
            account.updatedBy = identifier
        } else {
            let newAccount = AssetAccount(context: viewContext)
            newAccount.id = UUID()
            newAccount.name = trimmedName
            newAccount.type = type.rawValue
            newAccount.balance = NSDecimalNumber(decimal: balance)
            newAccount.note = noteValue
            newAccount.includeInTotal = includeInTotal
            newAccount.sortOrder = 0
            newAccount.createdAt = Date()
            newAccount.updatedAt = Date()
            newAccount.createdBy = identifier
            newAccount.updatedBy = identifier
        }

        do {
            try viewContext.save()
            HapticManager.shared.success()
            dismiss()
        } catch {
            HapticManager.shared.error()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAccount() {
        guard let account else { return }
        HapticManager.shared.medium()
        viewContext.delete(account)
        try? viewContext.save()
        dismiss()
    }
}

#Preview {
    AssetEditSheet(account: nil)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
