//
//  CustomCategorySheet.swift
//  iFinance
//
//  自定义分类编辑 sheet：名称 + 图标（精选库）+ 主题色 + 可选二级分类。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

struct CustomCategorySheet: View {
    enum Mode {
        case create
        case edit
    }

    let mode: Mode
    let kind: CategoryKind
    /// 新建二级分类时的父级 key（一级分类传 nil）
    var parentKey: String? = nil
    /// 编辑模式下的原分类
    var editing: CustomCategory? = nil

    var onCreated: (CustomCategory) -> Void = { _ in }
    var onRenamed: (_ oldPath: String, _ newPath: String) -> Void = { _, _ in }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = CategoryStore.shared

    @State private var name: String = ""
    @State private var icon: String = "tag"
    @State private var colorHex: String? = nil
    /// 新建一级分类时可一并添加的二级分类（名称 + 自动分配的图标）
    @State private var pendingSubcategories: [(name: String, icon: String)] = []
    @State private var newSubcategoryName: String = ""
    @State private var iconKeyword: String = ""
    @State private var errorMessage: String?

    private var isEditing: Bool { mode == .edit }
    private var showsSubcategorySection: Bool { mode == .create && parentKey == nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        nameSection
                        iconSection
                        colorSection
                        if showsSubcategorySection { subcategorySection }
                    }
                    .padding(AppSpacing.lg)
                    .appContentWidth()
                }
            }
            .navigationTitle(L10n.string(isEditing ? "category.custom.edit" : "category.custom.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .alert(
                errorMessage ?? "",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    // MARK: - 名称

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("category.custom.name")
            TextField(L10n.string("category.custom.name_placeholder"), text: $name)
                .textFieldStyle(.plain)
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            Text(String(format: L10n.string("category.custom.name_hint"), CategoryStore.maxNameLength))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 图标

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                sectionTitle("category.custom.icon")
                Spacer()
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(selectedColor))
            }

            TextField(L10n.string("category.custom.icon_search"), text: $iconKeyword)
                .textFieldStyle(.plain)
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )

            ForEach(CategoryIconLibrary.filtered(keyword: iconKeyword)) { group in
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(L10n.string(group.titleKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 6), spacing: AppSpacing.sm) {
                        ForEach(group.icons, id: \.self) { symbol in
                            iconButton(symbol)
                        }
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        }
    }

    private func iconButton(_ symbol: String) -> some View {
        let taken = isIconTaken(symbol)
        let selected = icon == symbol
        return Button {
            guard !taken else { return }
            HapticManager.shared.light()
            icon = symbol
        } label: {
            Image(systemName: symbol)
                .font(.callout)
                .foregroundStyle(selected ? .white : (taken ? Color.secondary : Color.primary))
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(selected ? selectedColor : Color.primary.opacity(taken ? 0.04 : 0.07))
                )
                .overlay(
                    Circle().strokeBorder(selected ? selectedColor.opacity(0.6) : .clear, lineWidth: 1.5)
                )
                .overlay(alignment: .bottom) {
                    if taken && !selected {
                        Text("category.custom.icon_in_use")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                            .offset(y: 6)
                    }
                }
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.9))
        .disabled(taken && !selected)
    }

    // MARK: - 主题色

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("category.custom.color")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 6), spacing: AppSpacing.sm) {
                autoColorButton
                ForEach(CategoryPalette.customColors, id: \.self) { hex in
                    Button {
                        HapticManager.shared.light()
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(CategoryPalette.color(hex: hex) ?? .gray)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().strokeBorder(Color.primary.opacity(colorHex == hex ? 0.8 : 0.1), lineWidth: colorHex == hex ? 2 : 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle(pressedScale: 0.9))
                }
            }
        }
    }

    private var autoColorButton: some View {
        Button {
            HapticManager.shared.light()
            colorHex = nil
        } label: {
            Text("category.custom.color_auto")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.primary.opacity(0.06)))
                .overlay(
                    Circle().strokeBorder(Color.primary.opacity(colorHex == nil ? 0.6 : 0.1), lineWidth: colorHex == nil ? 2 : 1)
                )
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.9))
    }

    // MARK: - 二级分类（仅新建一级分类时）

    private var subcategorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("category.custom.subcategory")

            ForEach(Array(pendingSubcategories.enumerated()), id: \.offset) { index, sub in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: sub.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text(sub.name)
                        .font(.subheadline)
                    Spacer()
                    Button {
                        pendingSubcategories.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }

            HStack(spacing: AppSpacing.sm) {
                TextField(L10n.string("category.custom.subcategory_placeholder"), text: $newSubcategoryName)
                    .textFieldStyle(.plain)
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )

                Button {
                    addPendingSubcategory()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
        }
    }

    private func addPendingSubcategory() {
        let trimmed = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= CategoryStore.maxNameLength,
              !trimmed.contains(CategoryStore.separator) else {
            errorMessage = L10n.string("category.custom.error.empty")
            return
        }
        guard !pendingSubcategories.contains(where: { $0.name == trimmed }) else {
            errorMessage = L10n.string("category.custom.error.duplicate")
            return
        }
        HapticManager.shared.light()
        pendingSubcategories.append((name: trimmed, icon: nextSubcategoryIcon()))
        newSubcategoryName = ""
    }

    /// 给新二级分类挑一个还没被占用的图标
    private func nextSubcategoryIcon() -> String {
        let used = Set(pendingSubcategories.map(\.icon)).union([icon])
        return CategoryIconLibrary.allIcons.first { !used.contains($0) } ?? "tag"
    }

    // MARK: - 保存

    private func save() {
        do {
            switch mode {
            case .create:
                let item = try store.add(kind: kind, name: name, icon: icon, colorHex: colorHex, parentKey: parentKey)
                for sub in pendingSubcategories {
                    _ = try? store.add(kind: kind, name: sub.name, icon: sub.icon, colorHex: nil, parentKey: item.key)
                }
                onCreated(item)
            case .edit:
                guard let editing else { return }
                let oldPath = store.storedPath(of: editing)
                try store.update(id: editing.id, name: name, icon: icon, colorHex: colorHex)
                let newPath = store.storedPath(of: editing, withNewName: name.trimmingCharacters(in: .whitespacesAndNewlines))
                if oldPath != newPath { onRenamed(oldPath, newPath) }
            }
            HapticManager.shared.success()
            dismiss()
        } catch {
            HapticManager.shared.error()
            errorMessage = error.localizedDescription
        }
    }

    private func loadIfEditing() {
        store.reload()
        guard let editing else { return }
        name = editing.name
        icon = editing.icon
        colorHex = editing.colorHex
    }

    // MARK: - 辅助

    private var selectedColor: Color {
        if let colorHex, let color = CategoryPalette.color(hex: colorHex) { return color }
        return CategoryPalette.autoColor(seed: name.isEmpty ? "new" : name, kind: kind)
    }

    private func isIconTaken(_ symbol: String) -> Bool {
        var taken = store.takenIcons(kind: kind, parentKey: parentKey)
        if let editing { taken.remove(editing.icon) }
        return taken.contains(symbol)
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.headline)
            .foregroundStyle(.primary)
    }
}
