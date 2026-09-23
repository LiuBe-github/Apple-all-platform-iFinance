//
//  IncomeCategoryItem.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/28.
//

import SwiftUI

struct IncomeCategoryItemView: View {
    let category: IncomeCategory
    
    @Binding var selectedCategory: IncomeCategory?
    
    var isSelected: Bool {
        return selectedCategory == category
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // 图标按钮
            Button(action: {
                // 如果不是当前选中的项目，则更改选择
                if selectedCategory != category {
                    selectedCategory = category
                }
            }) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(
                                isSelected
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.75)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color.gray.opacity(0.10))
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.green.opacity(0.4) : Color.gray.opacity(0.25),
                                    lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: isSelected ? Color.green.opacity(0.35) : .clear, radius: 5, x: 0, y: 2)
                    .symbolEffect(.bounce, value: isSelected)
                    .scaleEffect(isSelected ? 1.06 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSelected)
            }
            .disabled(isSelected) // 已选中的项目不可点击
            .buttonStyle(ScaleButtonStyle(pressedScale: 0.88))
            
            // 文字标签
            Text(category.localizedDisplayName)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .frame(width: 60, height: 66)
    }
}
