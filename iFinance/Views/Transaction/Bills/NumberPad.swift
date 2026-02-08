//
//  NumberPad.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/16.
//

import SwiftUI

struct NumberPad: View {
    @Binding var displayText: String
    @Binding var currentOperator: String
    @Binding var transactionType: AddBillView.TransactionType
    @Binding var note: String
    @Binding var selectedDate: Date
    @State private var isEditingNote = false
    @State private var showDatePicker = false
    
    let onSave: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 12) {
            // 金额输入框
            HStack {
                Text("¥")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                TextField("", text: $displayText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .keyboardType(.decimalPad)
                    .foregroundColor({
                        switch transactionType {
                        case .expenditure: return .red
                        case .income: return .green
                        case .transfer: return .yellow
                        }
                    }())
            }
            .padding(.horizontal)
            
            // 时间和备注
            HStack {
                Button(action: {
                    showDatePicker = true
                }) {
                    HStack {
                        Text(getFormattedDateString(selectedDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                ZStack {
                    if note.isEmpty && !isEditingNote {
                        Text("添加备注...")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    
                    TextField("", text: $note)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .onTapGesture {
                            isEditingNote = true
                        }
                        .onSubmit {
                            isEditingNote = false
                        }
                }
                .frame(maxWidth: 120)
            }
            .padding(.horizontal)
            
            // 数字键盘
            VStack(spacing: 8) {
                // 第一行
                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { num in
                        NumberButton(value: String(num)) {
                            handleNumberTap(String(num))
                        }
                    }
                    
                    // 操作按钮 - 加乘
                    OperationButton(
                        symbol: "+×",
                        color: .blue,
                        action: {
                            handleOperationTap("+", altOp: "×")
                        }
                    )
                }
                
                // 第二行
                HStack(spacing: 8) {
                    ForEach(4...6, id: \.self) { num in
                        NumberButton(value: String(num)) {
                            handleNumberTap(String(num))
                        }
                    }
                    
                    // 操作按钮 - 减除
                    OperationButton(
                        symbol: "-÷",
                        color: .purple,
                        action: {
                            handleOperationTap("-", altOp: "÷")
                        }
                    )
                }
                
                // 第三行
                HStack(spacing: 8) {
                    ForEach(7...9, id: \.self) { num in
                        NumberButton(value: String(num)) {
                            handleNumberTap(String(num))
                        }
                    }
                    
                    // 自定义按钮 - 百分比
                    OperationButton(
                        symbol: "%",
                        color: .orange,
                        action: {
                            handlePercentage()
                        }
                    )
                }
                
                // 第四行
                HStack(spacing: 8) {
                    NumberButton(value: ".", systemImage: "dot.square") {
                        handleNumberTap(".")
                    }
                    
                    NumberButton(value: "0") {
                        handleNumberTap("0")
                    }
                    
                    NumberButton(value: "delete", systemImage: "delete.backward") {
                        handleDeleteTap()
                    }
                    
                    // 完成按钮
                    Button(action: {
                        onSave?()
                    }) {
                        Text("完成")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $showDatePicker) {
            DatePickerView(selectedDate: $selectedDate, onConfirm: {
                showDatePicker = false
            })
        }
    }
    
    private func handleNumberTap(_ number: String) {
        // 如果当前显示的是0.00，则替换为新数字
        if displayText == "0.00" {
            displayText = number
        } else {
            // 防止输入多个小数点后的位数
            if displayText.contains(".") {
                let parts = displayText.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
                if parts.count > 1 {
                    let decimalPart = parts[1]
                    if decimalPart.count >= 2 && number != "." {
                        // 已经有两个小数位，不允许再输入数字
                        return
                    }
                }
            }
            displayText += number
        }
    }
    
    private func handleDeleteTap() {
        // 如果当前是0.00，不允许退格
        if displayText == "0.00" {
            return
        }
        
        // 如果只剩一个字符，重置为0.00
        if displayText.count <= 1 {
            displayText = "0.00"
        } else {
            displayText = String(displayText.dropLast())
        }
    }
    
    private func handleOperationTap(_ primaryOp: String, altOp: String) {
        // 确定当前操作符
        let newOp = (currentOperator == primaryOp) ? altOp : primaryOp
        
        // 更新当前操作符状态
        currentOperator = newOp
        
        // 如果显示文本以操作符结尾，则替换最后一个字符
        if let lastChar = displayText.last, ["+", "-", "×", "÷"].contains(String(lastChar)) {
            displayText = String(displayText.dropLast()) + newOp
        } else {
            // 否则追加操作符
            displayText += newOp
        }
    }
    
    private func handlePercentage() {
        // 百分比操作 - 将当前金额除以100
        if let value = Double(displayText), value != 0 {
            let newValue = value / 100
            displayText = String(format: "%.2f", newValue)
        }
    }
    
    private func getFormattedDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct NumberButton: View {
    let value: String
    let systemImage: String?
    let action: () -> Void
    
    init(value: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.value = value
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray5))
                    .frame(height: 50)
                
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(.primary)
                } else {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.medium)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct OperationButton: View {
    let symbol: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(height: 50)
                
                Text(symbol)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct DatePickerView: View {
    @Binding var selectedDate: Date
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("选择日期和时间", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                Spacer()
            }
            .navigationBarTitle("选择时间", displayMode: .inline)
            .navigationBarItems(
                leading: Button("取消") {
                    dismiss()
                },
                trailing: Button("确定") {
                    onConfirm()
                    dismiss()
                }
            )
        }
    }
}
