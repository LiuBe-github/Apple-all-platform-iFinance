//
//  AddBillView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/13.
//

import SwiftUI
internal import CoreData
import Foundation

struct AddBillView: View {
    enum TransactionType: Hashable {
        case expenditure
        case income
        case transfer
    }
    
    // 网格视图的行数和列数
    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var displayText: String = "0.00"
    @State private var note: String = ""
    @State private var isEditingNote = false
    @State private var transactionType: TransactionType = .expenditure
    @State private var selectedExpenditureCategory: ExpenditureCategory? = .foodAndBeverage
    @State private var selectedIncomeCategory: IncomeCategory? = .salary
    @State private var showNumberPad = true
    @State private var currentOperator: String = "+"
    @State private var selectedDate: Date = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 主要内容区域（可滚动）
                ScrollView {
                    VStack(alignment: .leading) {
                        if transactionType == .expenditure {
                            LazyVGrid(columns: columns, spacing: 35) {
                                ForEach(ExpenditureCategory.allCases, id: \.self) { category in
                                    ExpenditureCategoryItemView(category: category, selectedCategory:  $selectedExpenditureCategory)
                                        .onTapGesture {
                                            print("Selected category: \(category.rawValue)")
                                        }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, -10)
                        } else if transactionType == .income {
                            LazyVGrid(columns: columns, spacing: 35) {
                                ForEach(IncomeCategory.allCases, id: \.self) { category in
                                    IncomeCategoryItemView(category: category, selectedCategory:  $selectedIncomeCategory)
                                        .onTapGesture {
                                            print("Selected category: \(category.rawValue)")
                                        }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, -10)
                        } else { // MARK: 后期完善转账的基本逻辑
                            Text("此功能还在开发当中哦😀！敬请期待！")
                                .padding(.horizontal)
                        }
                        
                        // 占位符，确保内容不会被底部键盘遮挡
                        Color.clear
                            .frame(height: 300) // 键盘高度的占位
                    }
                }
                
                // 固定在底部的数字键盘
                if showNumberPad {
                    NumberPad(
                        displayText:  $displayText,
                        currentOperator:  $currentOperator,
                        transactionType:  $transactionType,
                        note:  $note,
                        selectedDate:  $selectedDate
                    ) {
                        saveBill()
                        // 解析显示文本获取最终数值
//                        let result = parseExpression(displayText)
                    }
                    .transition(.move(edge: .bottom))
                    .background(Color(UIColor.systemBackground).shadow(radius: 10))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .title) {
                    Picker("视图", selection:  $transactionType) {
                        Text("支出")
                            .tag(TransactionType.expenditure)
                        Text("收入")
                            .tag(TransactionType.income)
                        Text("转账")
                            .tag(TransactionType.transfer)
                    }
                    .frame(width: 300)
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
        }
        .alert(alertMessage, isPresented: $showingAlert) {
            Button("确定", role: .cancel){ }
        }
        
    }
    
    private func saveBill() {
        let result = parseExpression(displayText)
        guard result > 0 else {
            showAlert(message: "金额必须大于 0")
            return
        }
        
        let categoryString: String
        switch transactionType {
        case .expenditure:
            guard let cat = selectedExpenditureCategory else {
                showAlert(message: "请选择分类")
                return
            }
            categoryString = cat.rawValue
        case .income:
            guard let cat = selectedIncomeCategory else {
                showAlert(message: "请选择分类")
                return
            }
            categoryString = cat.rawValue
        case .transfer:
            categoryString = "transfer"
        }
        
        // 创建对象
        let newBill = Bill(context: viewContext)
        
        // 所有非可选字段必须赋非 nil 值
        newBill.id = UUID()                     // 👈 直接赋 UUID()，不是字符串！
        newBill.amount = NSDecimalNumber(value: result)
        newBill.date = selectedDate
        newBill.type = transactionType == .expenditure ? "expenditure" :
        transactionType == .income ? "income" : "transfer"
        newBill.category = categoryString       // 可为 nil
        newBill.note = note.isEmpty ? nil : note // 可为 nil
        newBill.createdAt = Date()
        newBill.createdBy = "user"
        newBill.updatedAt = Date()
        newBill.updatedBy = "user"
        // 尝试保存
        print(newBill.type ?? "nil")
        print(newBill.category ?? "nil")
        do {
            try viewContext.save()
            print("✅ 账单保存成功！")
            dismiss()
        } catch {
            let nsError = error as NSError
            print("❌ 保存失败: \(error.localizedDescription)")
            print("Domain: \(nsError.domain), Code: \(nsError.code)")
            showAlert(message: "保存失败，请查看控制台日志")
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
    
    private func getFormattedDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 解析表达式并计算结果
    private func parseExpression(_ expression: String) -> Double {
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
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
