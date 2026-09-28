//
//  EditBillView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/1.
//

import SwiftUI
import os
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
    @State private var alertMessageKey = "bill.amount_invalid_msg"
    @State private var showingDeleteConfirmation = false
    
    init(bill: Bill) {
        self.bill = bill
        
        // 初始化表单状态
        // 类型先归一化：历史数据可能是模型默认值「支出」等中文类型，直接用会导致
        // 分段控件无匹配项、分类校验永远失败（保存按钮点了没反应）
        let normalizedType = BillEditRules.normalizedType(bill.type)
        _amountString = State(initialValue: bill.amount?.stringValue ?? "")
        _selectedType = State(initialValue: normalizedType)
        _note = State(initialValue: bill.note ?? "")
        _categoryRawValue = State(initialValue: BillEditRules.normalizedCategory(bill.category, for: normalizedType))
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
                        .onChange(of: amountString) { _, newValue in
                            // 全角数字 / 中文句号 / 千分位统一成半角：
                            // 以前只保留 `0-9.`，第三方输入法或全角键盘输入的字符会被直接吃掉
                            let normalized = BillAmountInput.normalize(newValue)
                            if normalized != newValue {
                                amountString = normalized
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
                    // 不再用 .disabled 静默禁用：禁用会让「改完金额点保存毫无反应」，
                    // 用户不知道哪里不合法。改为点击后按具体原因弹提示。
                    Button("common.save") {
                        saveBill()
                    }
                    .fontWeight(.semibold)
                    .alert(L10n.string(alertMessageKey), isPresented: $showingAlert) {
                        Button("common.ok", role: .cancel) {}
                    }
                }
            }
        }
    }
    
    // 合法金额（> 0）
    private var amountValue: Double? {
        BillAmountInput.value(amountString)
    }

    private var isValidAmount: Bool {
        (amountValue ?? 0) > 0
    }

    /// 分类必须与当前类型匹配（转账固定 transfer）
    private var hasValidCategory: Bool {
        BillEditRules.isValid(categoryForSaving, for: selectedType)
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
        #if DEBUG
        Logger(subsystem: "com.liube.ifinance", category: "BillSave").notice("进入保存 amountString=\(amountString, privacy: .public) 解析值=\(String(describing: amountValue), privacy: .public)")
        #endif

        guard let amountDouble = amountValue, amountDouble > 0 else {
            HapticManager.shared.error()
            alertMessageKey = "bill.amount_invalid_msg"
            showingAlert = true
            #if DEBUG
            Logger(subsystem: "com.liube.ifinance", category: "BillSave").error("被金额校验拦下：amountString=\(amountString, privacy: .public)")
            #endif
            return
        }

        guard hasValidCategory else {
            HapticManager.shared.error()
            alertMessageKey = "bill.choose_category"
            showingAlert = true
            #if DEBUG
            Logger(subsystem: "com.liube.ifinance", category: "BillSave").error("被分类校验拦下：type=\(selectedType, privacy: .public) category=\(categoryForSaving ?? "-", privacy: .public)")
            #endif
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
            #if DEBUG
            Logger(subsystem: "com.liube.ifinance", category: "BillSave").notice("保存成功 amount=\(amountDouble, privacy: .public) 库内值=\(bill.amount?.doubleValue ?? -1, privacy: .public)")
            #endif
            dismiss()
        } catch {
            HapticManager.shared.error()
            Logger(subsystem: "com.liube.ifinance", category: "BillSave").error("保存账单失败：\(error.localizedDescription, privacy: .public)")
            alertMessageKey = "bill.save_failed"
            showingAlert = true
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
