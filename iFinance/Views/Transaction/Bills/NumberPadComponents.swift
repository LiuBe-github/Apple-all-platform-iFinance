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
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 54)
                
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundColor(.primary)
                } else {
                    Text(value)
                        .font(.system(size: value == "." ? 24 : 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.9))
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
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                            .strokeBorder(color.opacity(0.25), lineWidth: 1)
                    )
                
                Text(symbol)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(color)
            }
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.9))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 日期选择器

struct DatePickerView: View {
    @Binding var selectedDate: Date
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("bill.select_datetime", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                Spacer()
            }
            .navigationBarTitle("bill.select_time", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("auth.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.confirm") {
                        HapticManager.shared.medium()
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
