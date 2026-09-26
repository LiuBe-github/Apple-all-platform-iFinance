//
//  NumberPad.swift
//  iFinance
//
//  数字键盘主视图 - 用于 AddBillView 中的金额输入。
//  备注输入条不再在键盘内部浮动（那会与系统键盘避让叠加成双重位移），
//  改为由 AddBillView 的根级浮层按键盘高度定位；这里只保留一个「备注」按钮。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

struct NumberPad: View {
    @Binding var displayText: String
    @Binding var currentOperator: String
    @Binding var transactionType: AddBillView.TransactionType
    @Binding var note: String
    @Binding var selectedDate: Date

    @State private var showDatePicker = false
    @Environment(\.colorScheme) private var colorScheme

    /// 点备注行时回调（备注输入条由 AddBillView 负责展示与聚焦）
    let onBeginNoteEditing: () -> Void
    let onSave: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            inputHeader
            keypadGrid
        }
        .padding(.top, AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)
        .background(
            Color(UIColor.systemGroupedBackground)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppRadius.sheet, style: .continuous)
                )
        )
        .sheet(isPresented: $showDatePicker) {
            DatePickerView(selectedDate: $selectedDate, onConfirm: {
                showDatePicker = false
            })
        }
    }

    // MARK: - 输入条（金额 + 日期 + 备注）

    private var inputHeader: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Text("¥")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(displayText)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundColor(amountColor)
                    .contentTransition(.numericText())
                    .appAnimation(AppMotion.numeric, value: displayText)

                Spacer(minLength: AppSpacing.sm)
            }

            Divider()
                .foregroundStyle(.secondary.opacity(0.2))

            HStack(spacing: AppSpacing.md) {
                Button(action: {
                    HapticManager.shared.light()
                    showDatePicker = true
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(getFormattedDateString(selectedDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(ScaleButtonStyle(pressedScale: 0.92))

                Spacer(minLength: AppSpacing.sm)

                Button {
                    HapticManager.shared.light()
                    onBeginNoteEditing()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "square.and.pencil")
                            .font(.caption2)
                            .foregroundColor(note.isEmpty ? .secondary : .blue)

                        Text(note.isEmpty ? L10n.string("bill.note_add") : note)
                            .font(.caption)
                            .foregroundColor(note.isEmpty ? .gray : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(ScaleButtonStyle(pressedScale: 0.94))
                .frame(maxWidth: 180, alignment: .trailing)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - 数字键盘区

    private var keypadGrid: some View {
        VStack(spacing: AppSpacing.md) {
            // 第一行
            HStack(spacing: AppSpacing.sm) {
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
            HStack(spacing: AppSpacing.sm) {
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
            HStack(spacing: AppSpacing.sm) {
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
            HStack(spacing: AppSpacing.sm) {
                NumberButton(value: ".") {
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
                    HapticManager.shared.heavy() // 重要操作
                    onSave?()
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(AppTypography.body.weight(.semibold))
                        Text("common.done")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.55, blue: 0.45),
                                        Color(red: 0.95, green: 0.38, blue: 0.30)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(red: 0.95, green: 0.43, blue: 0.35).opacity(0.35), radius: 6, x: 0, y: 3)
                    )
                }
                .buttonStyle(ScaleButtonStyle(pressedScale: 0.94))
            }
        }
        .padding(.horizontal, AppSpacing.xs)
    }

    // MARK: - 辅助

    private var amountColor: Color {
        switch transactionType {
        case .expenditure: return ChartSeriesStyle.expense(for: colorScheme)
        case .income: return ChartSeriesStyle.income(for: colorScheme)
        case .transfer: return .orange
        }
    }

    // MARK: - 输入处理

    private func handleNumberTap(_ number: String) {
        // 触感反馈：数字按键 — 轻量高频
        HapticManager.shared.light()

        // 校验与拼接统一交给 NumberPadExpression（按「当前数字段」判断，支持运算符后的输入）
        let updated = NumberPadExpression.append(number, to: displayText)
        if updated == displayText {
            HapticManager.shared.error() // 无效输入：重复小数点 / 超出位数上限
        }
        displayText = updated
    }

    private func handleDeleteTap() {
        // 触感反馈：删除操作
        HapticManager.shared.rigid()

        displayText = NumberPadExpression.deleteLast(from: displayText)
    }

    private func handleOperationTap(_ primaryOp: String, altOp: String) {
        // 触感反馈：运算符
        HapticManager.shared.medium()

        // 第一次按插入主运算符，再按一次在本按钮的两个运算符之间切换
        let updated = NumberPadExpression.applyOperator(primary: primaryOp, alternate: altOp, to: displayText)
        displayText = updated
        if let last = updated.last, NumberPadExpression.operators.contains(last) {
            currentOperator = String(last)
        }
    }

    private func handlePercentage() {
        // 触感反馈：百分比转换
        HapticManager.shared.medium()

        // 百分比操作 - 将当前金额除以100
        displayText = NumberPadExpression.applyPercent(to: displayText)
    }

    private func getFormattedDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 组件已提取到 NumberPadComponents.swift
