//
//  NumberPad.swift
//  iFinance
//
//  数字键盘主视图 - 用于 AddBillView 中的金额输入
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
    @State private var keyboardHeight: CGFloat = 0
    /// 输入条实测高度（用于备注编辑时把键盘区折叠掉）
    @State private var headerHeight: CGFloat = 0
    @FocusState private var isNoteFocused: Bool
    
    let onSave: (() -> Void)?
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            inputHeader
            keypadGrid
        }
        .padding(.top, AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)
        // 备注编辑时只保留输入条（键盘区被系统键盘覆盖），并把输入条顶到键盘上方
        .frame(height: isFloatingNote ? headerHeight + AppSpacing.md : nil, alignment: .top)
        .clipped()
        .background(
            Color(UIColor.systemGroupedBackground)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppRadius.sheet, style: .continuous)
                )
        )
        // 用 offset 而非 padding：视觉上浮，但不改变布局高度（避免键盘弹出时把页面内容顶走）
        .offset(y: -keyboardLift)
        .appAnimation(AppMotion.standard, value: isFloatingNote)
        .appAnimation(AppMotion.standard, value: keyboardLift)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screenHeight = UIScreen.main.bounds.height
            let overlap = max(0, screenHeight - frame.origin.y)
            keyboardHeight = overlap
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .onChange(of: isNoteFocused) { _, focused in
            isEditingNote = focused
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerView(selectedDate: $selectedDate, onConfirm: {
                showDatePicker = false
            })
        }
    }

    // MARK: - 浮动状态

    /// 备注编辑中：键盘覆盖数字键盘，输入条浮到键盘上方
    private var isFloatingNote: Bool {
        isNoteFocused || isEditingNote
    }

    /// 上浮距离（扣除底部安全区，避免多顶一段）
    private var keyboardLift: CGFloat {
        guard isFloatingNote else { return 0 }
        return max(0, keyboardHeight - bottomSafeAreaInset)
    }

    private var bottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0
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
                    .foregroundColor({
                        switch transactionType {
                        case .expenditure: return .red
                        case .income: return .green
                        case .transfer: return .orange
                        }
                    }())
                    .contentTransition(.numericText())
                    .appAnimation(AppMotion.numeric, value: displayText)

                Spacer(minLength: AppSpacing.sm)

                if isFloatingNote {
                    Button {
                        HapticManager.shared.light()
                        isNoteFocused = false
                        isEditingNote = false
                    } label: {
                        Text("common.done")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.14))
                            )
                    }
                    .buttonStyle(ScaleButtonStyle(pressedScale: 0.92))
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            Divider()
                .foregroundStyle(.secondary.opacity(0.2))

            HStack(spacing: AppSpacing.md) {
                if !isFloatingNote {
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
                }

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "square.and.pencil")
                        .font(.caption2)
                        .foregroundColor(note.isEmpty ? .secondary : .blue)

                    ZStack(alignment: .leading) {
                        if note.isEmpty && !isEditingNote {
                            Text("bill.note_add")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }

                        TextField("", text: $note)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .focused($isNoteFocused)
                            .submitLabel(.done)
                            .onTapGesture {
                                isEditingNote = true
                                isNoteFocused = true
                            }
                            .onSubmit {
                                isEditingNote = false
                                isNoteFocused = false
                            }
                    }
                    .frame(maxWidth: isFloatingNote ? .infinity : 140, alignment: .trailing)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                )
                .frame(maxWidth: isFloatingNote ? .infinity : nil, alignment: .trailing)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            headerHeight = height
        }
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
