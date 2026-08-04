//
//  AddBillSheet.swift
//  MaciFinance
//

import SwiftUI
import CoreData

struct AddBillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var amountText = "0"
    @State private var selectedType: TransactionType = .expenditure
    @State private var selectedExpenditureCategory: ExpenditureCategory? = nil
    @State private var selectedIncomeCategory: IncomeCategory? = nil
    @State private var note = ""
    @State private var selectedDate = Date()

    enum TransactionType: String, CaseIterable {
        case expenditure, income
        var title: String {
            self == .expenditure ? L10n.string("mac.bill.filter_expense") : L10n.string("mac.bill.filter_income")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(L10n.string("mac.add.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(L10n.string("mac.add.add_bill"))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(L10n.string("mac.add.save"), action: saveBill)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {

                    // Type toggle + Amount
                    HStack(spacing: 16) {
                        // Type picker
                        Picker(L10n.string("mac.add.transaction_type"), selection: $selectedType) {
                            Text(L10n.string("mac.bill.filter_expense")).tag(TransactionType.expenditure)
                            Text(L10n.string("mac.bill.filter_income")).tag(TransactionType.income)
                        }
                        .pickerStyle(.segmented)

                        Spacer()

                        // Amount input
                        TextField(L10n.string("mac.add.amount"), text: $amountText)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                            .multilineTextAlignment(.trailing)
                    }

                    // Date picker
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                        Spacer()
                    }

                    // Category selection
                    categoryGrid

                    // Note
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("mac.add.note"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField(L10n.string("mac.add.note_placeholder"), text: $note)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Category Grid

    @ViewBuilder
    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("mac.add.category"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            if selectedType == .expenditure {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(ExpenditureCategory.allCases, id: \.self) { cat in
                        CategoryChip(
                            icon: cat.icon,
                            name: cat.localizedDisplayName,
                            isSelected: selectedExpenditureCategory == cat
                        ) { selectedExpenditureCategory = cat }
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(IncomeCategory.allCases, id: \.self) { cat in
                        CategoryChip(
                            icon: cat.icon,
                            name: cat.localizedDisplayName,
                            isSelected: selectedIncomeCategory == cat
                        ) { selectedIncomeCategory = cat }
                    }
                }
            }
        }
    }

    // MARK: - Validation & Save

    private var canSave: Bool {
        guard let val = Double(amountText), val > 0 else { return false }
        if selectedType == .expenditure && selectedExpenditureCategory == nil { return false }
        if selectedType == .income && selectedIncomeCategory == nil { return false }
        return true
    }

    private func saveBill() {
        let newBill = Bill(context: viewContext)
        newBill.id = UUID()
        newBill.amount = NSDecimalNumber(value: Double(amountText) ?? 0)
        newBill.date = selectedDate
        newBill.type = selectedType == .expenditure ? "expenditure" : "income"
        newBill.category = selectedType == .expenditure
            ? selectedExpenditureCategory?.rawValue
            : selectedIncomeCategory?.rawValue
        newBill.note = note.isEmpty ? L10n.string("mac.add.no_note") : note
        newBill.createdAt = Date()
        newBill.createdBy = "user"
        newBill.updatedAt = Date()
        newBill.updatedBy = "user"

        try? viewContext.save()
        dismiss()
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let icon: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(name)
                    .font(.system(size: 11))
            }
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            .foregroundStyle(isSelected ? .blue : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.blue.opacity(0.5) : Color(nsColor: .separatorColor), lineWidth: isSelected ? 1.2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
