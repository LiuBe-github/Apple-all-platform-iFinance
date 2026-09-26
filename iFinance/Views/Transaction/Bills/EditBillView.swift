//
//  EditBillView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/1.
//

import SwiftUI
internal import CoreData

struct EditBillView: View {
    @ObservedObject var bill: Bill
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    
    // 表单状态（绑定到 Core Data 属性）
    @State private var amountString = ""
    @State private var selectedType = "expenditure"
    @State private var note = ""
    /// 已选分类 rawValue（nil 表示未选择）
    @State private var categoryRawValue: String?
    @State private var selectedDate = Date()
    // MARK: - State for alert
    @State private var showingAlert = false
    @State private var showingDeleteConfirmation = false
    
    init(bill: Bill) {
        self.bill = bill
        
        // 初始化表单状态
        _amountString = State(initialValue: bill.amount?.stringValue ?? "")
        _selectedType = State(initialValue: bill.type ?? "expenditure")
        _note = State(initialValue: bill.note ?? "")
        _categoryRawValue = State(initialValue: BillEditRules.normalizedCategory(bill.category, for: bill.type ?? "expenditure"))
        _selectedDate = State(initialValue: bill.date ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("bill.date") {
                    DatePicker(
                        "bill.select_datetime",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                
                Section("bill.amount") {
                    TextField("bill.input_amount", text: $amountString)
                        .keyboardType(.decimalPad)
                        .onSubmit {
                            validateAmount()
                        }
                        .onChange(of: amountString) { _, newValue in
                            // 可选：实时清理非法字符（只保留数字和小数点）
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                amountString = filtered
                            }
                        }
                }
                
                Section("bill.type") {
                    Picker("bill.type_picker", selection: $selectedType) {
                        Text("bill.type_expenditure").tag("expenditure")
                        Text("bill.type_income").tag("income")
                        Text("bill.type_transfer").tag("transfer")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedType) { _, newType in
                        // 类型改变后原分类不再适用：支出/收入清空（需重选），转账固定为 transfer
                        categoryRawValue = BillEditRules.categoryAfterTypeChange(to: newType)
                    }
                }
                
                Section("bill.category") {
                    if selectedType == BillEditRules.transferType {
                        // 转账没有分类，固定展示「转账」
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundStyle(.secondary)
                            Text(L10n.string("bill.type_transfer"))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        NavigationLink {
                            CategoryPickerView(type: selectedType, selectedRawValue: $categoryRawValue)
                        } label: {
                            categoryRowLabel
                        }
                    }
                }
                
                Section("bill.note") {
                    TextField("bill.note_placeholder", text: $note)
                }
                
                Section {
                    Button("bill.delete") {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .alert("bill.delete_title", isPresented: $showingDeleteConfirmation) {
                        Button("auth.cancel", role: .cancel) {}
                        Button("bill.delete_confirm", role: .destructive) {
                            deleteBill()
                        }
                    } message: {
                        Text("bill.delete_message")
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
            }
            .navigationTitle("bill.edit_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save") {
                        saveBill()
                    }
                    .disabled(!isValidInput)
                    .alert("bill.amount_invalid", isPresented: $showingAlert) {
                        Button("common.ok", role: .cancel) {}
                    } message: {
                        Text("bill.amount_invalid_msg")
                    }
                    }
                }
        }
    }
    
    // 验证输入是否有效（至少金额要能转成数字）
    private var isValidInput: Bool {
        guard !amountString.isEmpty, let value = Double(amountString), value > 0 else { return false }
        // 分类必须与当前类型匹配（转账固定 transfer）
        return BillEditRules.isValid(categoryForSaving, for: selectedType)
    }

    /// 保存时写入的分类
    private var categoryForSaving: String? {
        selectedType == BillEditRules.transferType ? BillEditRules.transferCategory : categoryRawValue
    }

    /// 分类行内容：已选显示图标 + 本地化名称，未选显示占位
    private var categoryRowLabel: some View {
        HStack(spacing: AppSpacing.md) {
            if let raw = categoryRawValue, !raw.isEmpty {
                Image(systemName: categoryIcon(for: raw))
                    .foregroundStyle(selectedType == "income"
                                     ? ChartSeriesStyle.income(for: colorScheme)
                                     : ChartSeriesStyle.expense(for: colorScheme))
                Text(categoryDisplayName(for: raw))
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(.secondary)
                Text(L10n.string("bill.category_unselected"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func categoryIcon(for rawValue: String) -> String {
        CategoryResolver.icon(for: rawValue, kind: selectedType == "income" ? .income : .expenditure)
    }

    private func categoryDisplayName(for rawValue: String) -> String {
        CategoryResolver.displayName(for: rawValue, kind: selectedType == "income" ? .income : .expenditure)
    }
    
    private func saveBill() {
        guard let amountDouble = Double(amountString), amountDouble > 0 else {
            HapticManager.shared.error()
            showingAlert = true
            return
        }
        
        // 更新 Core Data 对象
        bill.amount = NSDecimalNumber(value: amountDouble)
        bill.type = selectedType
        bill.note = note
        bill.category = categoryForSaving
        bill.date = selectedDate
        
        // 保存上下文
        do {
            try viewContext.save()
            HapticManager.shared.success()
            dismiss()
        } catch {
            print("❌ 保存账单失败: \(error)")
        }
    }
    
    // 删除账单的函数
    private func deleteBill() {
        HapticManager.shared.heavy() // 重要操作
        // 从 Core Data 上下文中删除对象
        viewContext.delete(bill)
        
        do {
            try viewContext.save()
            print("✅ 账单删除成功")
            dismiss() // 返回到上一个页面
        } catch {
            print("❌ 删除账单失败: \(error)")
            // 可以在这里显示一个错误提示给用户
            showingAlert = true
        }
    }
    
    
    // MARK: - Validation
    private func validateAmount() {
        guard let amount = Double(amountString),
              amount > 0 else {
            showingAlert = true
            return
        }
        // 如果需要，可以在这里做其他处理（比如自动保存）
    }
}

// MARK: - 预览支持
#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // 创建预览用的账单
    let previewBill = Bill(context: context)
    previewBill.id = UUID()
    previewBill.amount = NSDecimalNumber(string: "123.45")
    previewBill.type = "expenditure"
    previewBill.category = "餐饮"
    previewBill.note = "午餐"
    previewBill.date = Date()
    
    return NavigationStack {
        EditBillView(bill: previewBill)
    }
    .environment(\.managedObjectContext, context)
}
