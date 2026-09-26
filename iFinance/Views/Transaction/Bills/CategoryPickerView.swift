//
//  CategoryPickerView.swift
//  iFinance
//
//  分类选择页：只列出指定账单类型（支出 / 收入）的分类网格，点选后写回并返回。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

struct CategoryPickerView: View {
    /// `"expenditure"` / `"income"`
    let type: String
    @Binding var selectedRawValue: String?

    @Environment(\.dismiss) private var dismiss

    @State private var showingCustomCategorySheet = false

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView(showsIndicators: false) {
                CategoryGridView(kind: kind, selection: selectionBinding) {
                    showingCustomCategorySheet = true
                }
                .padding(.vertical, AppSpacing.lg)
                .appContentWidth()
            }
        }
        .navigationTitle(L10n.string("bill.select_category"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCustomCategorySheet) {
            CustomCategorySheet(mode: .create, kind: kind) { item in
                select(item.name)
            }
        }
        .onAppear { CategoryStore.shared.reload() }
    }

    // MARK: - 类型与选择

    private var kind: CategoryKind {
        type == "income" ? .income : .expenditure
    }

    /// 选中即写回并返回上一页
    private var selectionBinding: Binding<String?> {
        Binding(
            get: { selectedRawValue },
            set: { newValue in
                guard let newValue, !newValue.isEmpty else { return }
                select(newValue)
            }
        )
    }

    private func select(_ rawValue: String) {
        HapticManager.shared.light()
        selectedRawValue = rawValue
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CategoryPickerView(type: "expenditure", selectedRawValue: .constant("餐饮"))
    }
}
