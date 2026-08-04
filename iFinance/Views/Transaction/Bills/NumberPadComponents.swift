//
//  NumberPadComponents.swift
//  iFinance
//
//  数字键盘组件 - 从 NumberPad.swift 提取的可复用组件
//

import SwiftUI

// MARK: - 数字按钮

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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 54)
                
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(.primary)
                } else {
                    if value == "." {
                        Text(value)
                            .font(.title2)
                            .fontWeight(.semibold)
                    } else {
                        Text(value)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 操作按钮

struct OperationButton: View {
    let symbol: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 54)
                
                Text(symbol)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 日期选择器

struct DatePickerView: View {
    @Binding var selectedDate: Date
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("bill.select_datetime", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                Spacer()
            }
            .navigationBarTitle("bill.select_time", displayMode: .inline)
            .navigationBarItems(
                leading: Button("auth.cancel") {
                    dismiss()
                },
                trailing: Button("common.confirm") {
                    onConfirm()
                    dismiss()
                }
            )
        }
    }
}
