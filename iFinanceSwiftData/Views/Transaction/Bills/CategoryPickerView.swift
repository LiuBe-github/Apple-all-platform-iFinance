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

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 5)

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Self.columns, spacing: AppSpacing.xl) {
                    if type == "income" {
                        ForEach(IncomeCategory.allCases, id: \.self) { category in
                            IncomeCategoryItemView(category: category, selectedCategory: incomeSelection)
                                .onTapGesture { select(category.rawValue) }
                        }
                    } else {
                        ForEach(ExpenditureCategory.allCases, id: \.self) { category in
                            ExpenditureCategoryItemView(category: category, selectedCategory: expenditureSelection)
                                .onTapGesture { select(category.rawValue) }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
                .appContentWidth()
            }
        }
        .navigationTitle(L10n.string("bill.select_category"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 选择回写

    private func select(_ rawValue: String) {
        HapticManager.shared.light()
        selectedRawValue = rawValue
        dismiss()
    }

    /// 支出分类选择桥接（把 item 视图的选中回写到 rawValue 并返回上一页）
    private var expenditureSelection: Binding<ExpenditureCategory?> {
        Binding(
            get: { selectedRawValue.flatMap(ExpenditureCategory.init(rawValue:)) },
            set: { newValue in
                guard let newValue else { return }
                select(newValue.rawValue)
            }
        )
    }

    private var incomeSelection: Binding<IncomeCategory?> {
        Binding(
            get: { selectedRawValue.flatMap(IncomeCategory.init(rawValue:)) },
            set: { newValue in
                guard let newValue else { return }
                select(newValue.rawValue)
            }
        )
    }
}

#Preview {
    NavigationStack {
        CategoryPickerView(type: "expenditure", selectedRawValue: .constant("餐饮"))
    }
}
