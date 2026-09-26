//
//  AddBillView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/13.
//

import SwiftUI
import SwiftData
import Foundation

struct AddBillView: View {
    enum TransactionType: Hashable {
        case expenditure
        case income
        case transfer
    }
    
    // 网格视图的行数和列数
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var viewContext
    
    @State private var displayText: String = "0.00"
    @State private var note: String = ""
    @State private var isEditingNote = false
    @State private var transactionType: TransactionType = .expenditure
    /// 当前选中的分类（账单里存储的字符串：内置 rawValue / 自定义名 / 「父/子」复合路径）
    @State private var selectedCategoryRaw: String? = ExpenditureCategory.foodAndBeverage.rawValue
    @State private var showingCustomCategorySheet = false
    @State private var showNumberPad = true
    /// 最近一次按下的运算符（由数字键盘回写；表达式本身以 displayText 为准）
    @State private var currentOperator: String = ""
    @State private var selectedDate: Date = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var transferFrom: String = ""
    @State private var transferTo: String = ""
    
    var body: some View {
        NavigationStack {
            // 主要内容区域（可滚动）
            ScrollView {
                VStack(alignment: .leading) {
                    Group {
                        if transactionType == .expenditure {
                            CategoryGridView(kind: .expenditure, selection: $selectedCategoryRaw) {
                                showingCustomCategorySheet = true
                            }
                        } else if transactionType == .income {
                            CategoryGridView(kind: .income, selection: $selectedCategoryRaw) {
                                showingCustomCategorySheet = true
                            }
                        } else {
                            transferForm
                        }
                    }
                    .id(transactionType)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .appAnimation(AppMotion.standard, value: transactionType)
                }
            }
            // 键盘弹出时不顶走页面（备注条由 NumberPad 自行浮到键盘上方）
            .ignoresSafeArea(.keyboard, edges: .bottom)
            // 数字键盘固定在底部；由系统为滚动内容预留等高内边距（修复最后一排分类被遮挡）
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showNumberPad {
                    NumberPad(
                        displayText: $displayText,
                        currentOperator: $currentOperator,
                        transactionType: $transactionType,
                        note: $note,
                        selectedDate: $selectedDate
                    ) {
                        saveBill()
                    }
                    .transition(.move(edge: .bottom))
                    .background(alignment: .bottom) {
                        Color(UIColor.systemGroupedBackground)
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.shared.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .title) {
                    Picker("bill.view_picker", selection:  $transactionType) {
                        Text("bill.type_expenditure")
                            .tag(TransactionType.expenditure)
                        Text("bill.type_income")
                            .tag(TransactionType.income)
                        Text("bill.type_transfer")
                            .tag(TransactionType.transfer)
                    }
                    .frame(width: 300)
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .onChange(of: transactionType) { _, newType in
                // 切换类型后若当前分类不属于新类型，回退到该类型的默认分类
                guard let kind = CategoryKind(billType: newType == .expenditure ? "expenditure" :
                                              newType == .income ? "income" : "transfer") else { return }
                if selectedCategoryRaw.map({ CategoryResolver.isValid($0, kind: kind) }) != true {
                    selectedCategoryRaw = kind == .expenditure
                        ? ExpenditureCategory.foodAndBeverage.rawValue
                        : IncomeCategory.salary.rawValue
                }
            }
            .onAppear { CategoryStore.shared.reload() }
            .sheet(isPresented: $showingCustomCategorySheet) {
                CustomCategorySheet(
                    mode: .create,
                    kind: transactionType == .income ? .income : .expenditure
                ) { item in
                    selectedCategoryRaw = item.name
                }
            }
        }
        .alert(alertMessage, isPresented: $showingAlert) {
            Button("common.ok", role: .cancel){ }
        }
        
    }
    
    // MARK: - 转账表单
    private var transferForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("bill.transfer_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: AppSpacing.md) {
                transferField(
                    titleKey: "bill.transfer_from",
                    text: $transferFrom,
                    systemImage: "arrow.up.right"
                )

                transferField(
                    titleKey: "bill.transfer_to",
                    text: $transferTo,
                    systemImage: "arrow.down.left"
                )
            }

            Button {
                HapticManager.shared.medium()
                withAnimation(AppMotion.standard) {
                    swap(&transferFrom, &transferTo)
                }
            } label: {
                Label("bill.transfer_swap", systemImage: "arrow.left.arrow.right")
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding(.horizontal)
    }
    
    private func saveBill() {
        let result = parseExpression(displayText)
        guard result > 0 else {
            showAlert(message: L10n.string("bill.amount_gt_zero"))
            return
        }
        
        let categoryString: String
        switch transactionType {
        case .expenditure:
            guard let raw = selectedCategoryRaw, CategoryResolver.isValid(raw, kind: .expenditure) else {
                showAlert(message: L10n.string("bill.choose_category"))
                return
            }
            categoryString = raw
        case .income:
            guard let raw = selectedCategoryRaw, CategoryResolver.isValid(raw, kind: .income) else {
                showAlert(message: L10n.string("bill.choose_category"))
                return
            }
            categoryString = raw
        case .transfer:
            guard !transferFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !transferTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                showAlert(message: L10n.string("bill.transfer_account_required"))
                return
            }
            categoryString = "transfer"
        }
        
        // 创建对象（SwiftData）
        let newBill = Bill()
        viewContext.insert(newBill)
        
        // 所有非可选字段必须赋非nil值
        newBill.id = UUID()
        newBill.amount = Decimal(result)
        newBill.date = selectedDate
        newBill.type = transactionType == .expenditure ? "expenditure" :
        transactionType == .income ? "income" : "transfer"
        newBill.category = categoryString
        if transactionType == .transfer {
            let route = "\(transferFrom) → \(transferTo)"
            if note.isEmpty {
                newBill.note = route
            } else {
                newBill.note = "\(note) · \(route)"
            }
        } else {
            newBill.note = note.isEmpty ? nil : note
        }
        newBill.createdAt = Date()
        newBill.createdBy = AuthManager.shared.userIdentifier
        newBill.updatedAt = Date()
        newBill.updatedBy = AuthManager.shared.userIdentifier
        // 尝试保存
        do {
            try viewContext.save()
            HapticManager.shared.success()
            dismiss()
        } catch {
            HapticManager.shared.error()
            showAlert(message: L10n.string("bill.save_failed"))
        }
    }
    
    private func showAlert(message: String) {
        HapticManager.shared.warning()
        alertMessage = message
        showingAlert = true
    }
    
    private func transferField(titleKey: LocalizedStringKey, text: Binding<String>, systemImage: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 22)
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // 解析表达式并计算结果
    /// 解析并计算表达式（如 "12.5+30"）；对测试可见，便于覆盖四则运算
    func parseExpression(_ expression: String) -> Double {
        // 移除所有操作符
        let numbersOnly = expression.replacingOccurrences(of: "[^0-9.]", with: " ", options: .regularExpression)
        let numberStrings = numbersOnly.components(separatedBy: " ").filter { !$0.isEmpty }
        
        // 提取数字
        var numbers: [Double] = []
        for numberStr in numberStrings {
            if let number = Double(numberStr) {
                // 修正前导零，例如05.22变为5.22
                let formattedNumber = formatNumber(number)
                numbers.append(formattedNumber)
            }
        }
        
        // 如果只有一个数字，直接返回
        guard numbers.count > 1 else {
            return numbers.first ?? 0.0
        }
        
        // 提取操作符
        let operators = extractOperators(from: expression)
        
        // 执行计算
        var result = numbers[0]
        for i in 1..<numbers.count {
            if i-1 < operators.count {
                switch operators[i-1] {
                case "+":
                    result += numbers[i]
                case "-":
                    result -= numbers[i]
                case "×":
                    result *= numbers[i]
                case "÷":
                    if numbers[i] != 0 {
                        result /= numbers[i]
                    }
                default:
                    break
                }
            }
        }
        
        return result
    }
    
    private func extractOperators(from expression: String) -> [String] {
        var operators: [String] = []
        var currentNumber = ""
        
        for char in expression {
            if char.isNumber || char == "." {
                currentNumber += String(char)
            } else {
                if !currentNumber.isEmpty {
                    currentNumber = ""
                }
                if ["+", "-", "×", "÷"].contains(String(char)) {
                    operators.append(String(char))
                }
            }
        }
        
        return operators
    }
    
    private func formatNumber(_ number: Double) -> Double {
        // 修正前导零，例如05.22变为5.22
        let stringRep = String(number)
        if let doubleValue = Double(stringRep) {
            return doubleValue
        }
        return number
    }
}

#Preview {
    AddBillView()
        .environment(\.modelContext, PersistenceController.preview.container.viewContext)
}
