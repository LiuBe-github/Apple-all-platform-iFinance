//
//  CategoryManagementView.swift
//  iFinance
//
//  设置 → 分类管理：自定义分类的新增/改名/删除，以及各分类的二级分类管理。
//  改名会同步更新该账号历史账单；删除只从选择器移除，历史账单原样保留。
//

import SwiftUI
internal import CoreData

struct CategoryManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        predicate: PersistenceController.billUserPredicate,
        animation: .default
    ) private var bills: FetchedResults<Bill>

    @ObservedObject private var store = CategoryStore.shared

    @State private var kind: CategoryKind = .expenditure
    @State private var showingCreateSheet = false
    @State private var editingItem: CustomCategory?
    @State private var deletingItem: CustomCategory?

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Picker("", selection: $kind) {
                        Text("category.manage.expenditure").tag(CategoryKind.expenditure)
                        Text("category.manage.income").tag(CategoryKind.income)
                    }
                    .pickerStyle(.segmented)

                    customSection
                    builtInSection
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .appContentWidth()
            }
        }
        .navigationTitle("category.manage.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.shared.light()
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CustomCategorySheet(mode: .create, kind: kind)
        }
        .sheet(item: $editingItem) { item in
            CustomCategorySheet(
                mode: .edit,
                kind: item.kind,
                editing: item,
                onRenamed: { oldPath, newPath in
                    renameBills(from: oldPath, to: newPath)
                }
            )
        }
        .confirmationDialog(
            L10n.string("category.manage.delete_title"),
            isPresented: Binding(
                get: { deletingItem != nil },
                set: { if !$0 { deletingItem = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletingItem
        ) { item in
            Button("common.delete", role: .destructive) {
                HapticManager.shared.success()
                store.delete(id: item.id)
            }
            Button("common.cancel", role: .cancel) { }
        } message: { _ in
            Text("category.manage.delete_message")
        }
        .onAppear { store.reload() }
    }

    // MARK: - 自定义分类

    private var customSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("category.manage.custom")

            if store.topLevel(kind).isEmpty {
                hint("category.manage.custom_empty")
            } else {
                ForEach(store.topLevel(kind)) { item in
                    row(
                        icon: item.icon,
                        title: CategoryResolver.displayName(for: item.name, kind: kind),
                        color: CategoryResolver.color(for: item.name, kind: kind),
                        subtitle: subcategoryCountText(for: item),
                        destination: SubcategoryManageView(parentRaw: item.name, kind: kind)
                    ) {
                        Menu {
                            Button("category.manage.rename") { editingItem = item }
                            Button("common.delete", role: .destructive) { deletingItem = item }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 内置分类

    private var builtInSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("category.manage.builtin")

            ForEach(CategoryResolver.topLevelOptions(kind: kind).filter { !$0.isCustom }) { option in
                row(
                    icon: option.icon,
                    title: option.title,
                    color: option.color,
                    subtitle: builtInSubcategoryCountText(for: option.raw),
                    destination: SubcategoryManageView(parentRaw: option.raw, kind: kind)
                )
            }
        }
    }

    // MARK: - 组件

    private func sectionHeader(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func hint(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
    }

    @ViewBuilder
    private func row<Trailing: View>(
        icon: String,
        title: String,
        color: Color,
        subtitle: String?,
        destination: some View,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            NavigationLink {
                destination
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(color))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            trailing()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func subcategoryCountText(for item: CustomCategory) -> String {
        let count = store.subcategories(parentKey: item.key, kind: item.kind).count
        return count == 0 ? L10n.string("category.manage.no_subcategory") : String(format: L10n.string("category.manage.subcategory_count"), count)
    }

    private func builtInSubcategoryCountText(for raw: String) -> String {
        let count = CategoryResolver.subOptions(forParent: raw, kind: kind).count
        return count == 0 ? L10n.string("category.manage.no_subcategory") : String(format: L10n.string("category.manage.subcategory_count"), count)
    }

    // MARK: - 改名同步历史账单

    private func renameBills(from oldPath: String, to newPath: String) {
        var changed = false
        for bill in bills {
            guard let raw = bill.category else { continue }
            if raw == oldPath {
                bill.category = newPath
                changed = true
            } else if raw.hasPrefix(oldPath + CategoryStore.separator) {
                bill.category = newPath + String(raw.dropFirst(oldPath.count))
                changed = true
            }
        }
        if changed, viewContext.hasChanges {
            try? viewContext.save()
        }
    }
}

// MARK: - 二级分类管理

struct SubcategoryManageView: View {
    let parentRaw: String
    let kind: CategoryKind

    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        predicate: PersistenceController.billUserPredicate,
        animation: .default
    ) private var bills: FetchedResults<Bill>

    @ObservedObject private var store = CategoryStore.shared

    @State private var showingAddSheet = false
    @State private var editingItem: CustomCategory?
    @State private var deletingItem: CustomCategory?

    private var parentKey: String? {
        CategoryResolver.parentKey(forStoredParent: parentRaw, kind: kind)
    }

    private var items: [CustomCategory] {
        guard let parentKey else { return [] }
        return store.subcategories(parentKey: parentKey, kind: kind)
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if items.isEmpty {
                        Text("category.manage.sub_empty")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                    } else {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .appContentWidth()
            }
        }
        .navigationTitle(CategoryResolver.displayName(for: parentRaw, kind: kind))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.shared.light()
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(parentKey == nil)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CustomCategorySheet(mode: .create, kind: kind, parentKey: parentKey)
        }
        .sheet(item: $editingItem) { item in
            CustomCategorySheet(
                mode: .edit,
                kind: kind,
                editing: item,
                onRenamed: { oldPath, newPath in
                    renameBills(from: oldPath, to: newPath)
                }
            )
        }
        .confirmationDialog(
            L10n.string("category.manage.delete_title"),
            isPresented: Binding(
                get: { deletingItem != nil },
                set: { if !$0 { deletingItem = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletingItem
        ) { item in
            Button("common.delete", role: .destructive) {
                HapticManager.shared.success()
                store.delete(id: item.id)
            }
            Button("common.cancel", role: .cancel) { }
        } message: { _ in
            Text("category.manage.delete_message")
        }
        .onAppear { store.reload() }
    }

    private func itemRow(_ item: CustomCategory) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: item.icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(CategoryResolver.color(for: parentRaw + CategoryStore.separator + item.name, kind: kind)))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.builtInKey.map { L10n.string($0) } ?? item.name)
                    .font(.body)
                if item.builtInKey != nil {
                    Text(item.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                Button("category.manage.rename") { editingItem = item }
                Button("common.delete", role: .destructive) { deletingItem = item }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func renameBills(from oldPath: String, to newPath: String) {
        var changed = false
        for bill in bills {
            guard let raw = bill.category else { continue }
            if raw == oldPath {
                bill.category = newPath
                changed = true
            } else if raw.hasPrefix(oldPath + CategoryStore.separator) {
                bill.category = newPath + String(raw.dropFirst(oldPath.count))
                changed = true
            }
        }
        if changed, viewContext.hasChanges {
            try? viewContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        CategoryManagementView()
    }
}
