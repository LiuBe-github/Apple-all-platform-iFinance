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
    @Environment(\.managedObjectContext) private var viewContext
    
    // 表单状态（绑定到 Core Data 属性）
    @State private var amountString = ""
    @State private var selectedType = "expenditure"
    @State private var note = ""
    @State private var category = ""
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
        _category = State(initialValue: bill.category ?? "")
        _selectedDate = State(initialValue: bill.date ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("bill.date") {
                    DatePicker(
                        "bill.select_date",
                        selection: $selectedDate,
                        displayedComponents: .date
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
                .alert("bill.amount_invalid", isPresented: $showingAlert) {
                    Button("common.ok", role: .cancel) {}
                } message: {
                    Text("bill.amount_invalid_msg")
                }
                
                Section("bill.type") {
                    Picker("bill.type_picker", selection: $selectedType) {
                        Text("bill.type_expenditure").tag("expenditure")
                        Text("bill.type_income").tag("income")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("bill.category") {
                    TextField("bill.category_placeholder", text: $category)
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
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    // 验证输入是否有效（至少金额要能转成数字）
    private var isValidInput: Bool {
        !amountString.isEmpty && Double(amountString) != nil
    }
    
    private func setupInitialValues() {
        amountString = bill.amount?.stringValue ?? ""
        selectedType = bill.type ?? "expenditure"
        note = bill.note ?? ""
        category = bill.category ?? ""
        selectedDate = bill.date ?? Date()
    }
    
    private func saveBill() {
        guard let amountDouble = Double(amountString), amountDouble > 0 else {
            showingAlert = true
            return
        }
        
        // 更新 Core Data 对象
        bill.amount = NSDecimalNumber(value: amountDouble)
        bill.type = selectedType
        bill.note = note
        bill.category = category
        bill.date = selectedDate
        
        // 保存上下文
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("❌ 保存账单失败: \(error)")
        }
    }
    
    // 删除账单的函数
    private func deleteBill() {
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
