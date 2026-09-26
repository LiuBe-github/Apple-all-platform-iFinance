//
//  CategoryGridView.swift
//  iFinance
//
//  分类网格（内置 + 自定义 + 「+ 自定义」入口）与二级分类 chips。
//  新增账单页与编辑页的分类选择页共用。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

struct CategoryGridView: View {
    let kind: CategoryKind
    @Binding var selection: String?
    let onRequestCustom: () -> Void

    @ObservedObject private var store = CategoryStore.shared

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            LazyVGrid(columns: Self.columns, spacing: AppSpacing.xl) {
                ForEach(options) { option in
                    CategoryGridCell(
                        option: option,
                        isSelected: isSelected(option)
                    ) {
                        select(option)
                    }
                }
                addCustomTile
            }
            .padding(.horizontal, AppSpacing.md)

            if !subOptions.isEmpty {
                subcategoryChips
            }
        }
        .onAppear { store.reload() }
    }

    // MARK: - 数据

    private var options: [CategoryOption] {
        CategoryResolver.topLevelOptions(kind: kind)
    }

    /// 当前选中项下的二级分类
    private var subOptions: [CategoryOption] {
        guard let parent = selectionParentName else { return [] }
        return CategoryResolver.subOptions(forParent: parent, kind: kind)
    }

    /// 当前选中路径的一级名
    private var selectionParentName: String? {
        guard let selection, !selection.isEmpty else { return nil }
        return CategoryResolver.parentRaw(selection)
    }

    // MARK: - 子视图

    private var addCustomTile: some View {
        VStack(spacing: AppSpacing.xs) {
            Button {
                HapticManager.shared.light()
                onRequestCustom()
            } label: {
                Image(systemName: "plus")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.gray.opacity(0.06)))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                Color.secondary.opacity(0.45),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle(pressedScale: 0.88))

            Text("category.custom.new")
                .font(.system(size: 10))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60, height: 66)
    }

    private var subcategoryChips: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("category.custom.subcategory")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(subOptions) { option in
                        let selected = selection == option.raw
                        Button {
                            HapticManager.shared.light()
                            // 再点已选中的子分类 = 取消，回到父分类
                            selection = selected ? CategoryResolver.parentRaw(option.raw) : option.raw
                        } label: {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: option.icon)
                                    .font(.caption2)
                                Text(option.title)
                                    .font(.caption)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                Capsule().fill(selected ? option.color.opacity(0.20) : Color.primary.opacity(0.06))
                            )
                            .overlay(
                                Capsule().strokeBorder(selected ? option.color.opacity(0.6) : .clear, lineWidth: 1)
                            )
                            .foregroundStyle(selected ? option.color : Color.secondary)
                        }
                        .buttonStyle(ScaleButtonStyle(pressedScale: 0.94))
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: - 选择

    private func isSelected(_ option: CategoryOption) -> Bool {
        guard let selection else { return false }
        return CategoryResolver.parentRaw(selection) == option.raw
    }

    private func select(_ option: CategoryOption) {
        HapticManager.shared.light()
        // 点一级分类：回到父级（清掉子分类）
        selection = option.raw
    }
}

// MARK: - 网格单元

struct CategoryGridCell: View {
    let option: CategoryOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Button(action: action) {
                Image(systemName: option.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(
                            isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [option.color, option.color.opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color.gray.opacity(0.10))
                        )
                    )
                    .overlay(
                        Circle().stroke(
                            isSelected ? option.color.opacity(0.4) : Color.gray.opacity(0.25),
                            lineWidth: isSelected ? 2 : 1
                        )
                    )
                    .shadow(color: isSelected ? option.color.opacity(0.35) : .clear, radius: 5, x: 0, y: 2)
                    .symbolEffect(.bounce, value: isSelected)
                    .scaleEffect(isSelected ? 1.06 : 1)
                    .appAnimation(AppMotion.standard, value: isSelected)
            }
            .buttonStyle(ScaleButtonStyle(pressedScale: 0.88))

            Text(option.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .frame(width: 60, height: 66)
    }
}
