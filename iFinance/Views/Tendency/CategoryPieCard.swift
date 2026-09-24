//
//  CategoryPieCard.swift
//  iFinance
//
//  趋势页的分类占比卡片（支出 / 收入各一张，各自独立选择时间跨度）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

struct CategoryPieCard: View {
    /// 卡片标题的本地化 key
    let titleKey: String
    let accent: Color
    let kind: CategoryKind
    /// `"expenditure"` / `"income"`
    let billType: String
    let allBills: [Bill]

    @Binding var span: SpanOption

    private var slices: [CategorySlice] {
        CategoryBreakdown.slices(bills: allBills, type: billType, days: span.days)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(L10n.string(titleKey))
                .font(.headline)
                .fontWeight(.semibold)

            Picker("", selection: $span) {
                ForEach(SpanOption.all) { item in
                    Text(LocalizedStringKey(item.titleKey)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: span) { _, _ in
                HapticManager.shared.selectionChanged()
            }

            CategoryPieView(
                slices: slices,
                accent: accent,
                kind: kind,
                emptyKey: "tendency.category.empty"
            )
            // 切换跨度时重置扇区选中态
            .id(span.days)
        }
        .padding(TendencyConstants.cardPadding)
        .appGlassCard(cornerRadius: TendencyConstants.cardCornerRadius)
    }
}

#Preview {
    CategoryPieCard(
        titleKey: "tendency.expense_categories",
        accent: .pink,
        kind: .expenditure,
        billType: "expenditure",
        allBills: [],
        span: .constant(SpanOption.all[1])
    )
    .padding()
}
