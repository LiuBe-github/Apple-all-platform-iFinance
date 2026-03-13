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
        VStack(spacing: 2) {
            // 图标按钮
            Button(action: {
                // 如果不是当前选中的项目，则更改选择
                if selectedCategory != category {
                    selectedCategory = category
                }
            }) {
                Image(systemName: category.icon)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .black)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.green : Color.gray.opacity(0.1))
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            }
            .disabled(isSelected) // 已选中的项目不可点击
            .buttonStyle(PlainButtonStyle())
            
            // 文字标签
            Text(category.localizedDisplayName)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(.primary)
        }
        .frame(width: 55, height: 30)
    }
}
