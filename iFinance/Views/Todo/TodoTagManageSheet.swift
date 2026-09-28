//
//  TodoTagManageSheet.swift
//  iFinance
//
//  标签管理：重命名 / 删除（删除只解除待办与标签的关联，待办本身保留）。
//  重名校验复用 `TodoTagRules`（1–8 字、忽略大小写与音标去重）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改动请同步另一处。
//

import SwiftUI
internal import CoreData

struct TodoTagManageSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TodoTag.name, ascending: true)],
        predicate: PersistenceController.todoTagUserPredicate,
        animation: .default
    ) private var tags: FetchedResults<TodoTag>

    @State private var renamingTag: TodoTag?
    @State private var renameText = ""
    @State private var errorMessage: String?
    @State private var pendingDelete: TodoTag?
    @State private var showsDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                Group {
                    if tags.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(tags) { tag in
                                tagRow(tag)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(
                                        EdgeInsets(
                                            top: AppSpacing.xs,
                                            leading: AppSpacing.screen,
                                            bottom: AppSpacing.xs,
                                            trailing: AppSpacing.screen
                                        )
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            pendingDelete = tag
                                            showsDeleteConfirm = true
                                        } label: {
                                            Label("common.delete", systemImage: "trash")
                                        }

                                        Button {
                                            beginRename(tag)
                                        } label: {
                                            Label("todo.tag.rename", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
                    }
                }
                .appContentWidth()
            }
            .navigationTitle("todo.tag.manage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .alert(
                L10n.string("todo.tag.rename_title"),
                isPresented: Binding(
                    get: { renamingTag != nil },
                    set: { if !$0 { renamingTag = nil } }
                )
            ) {
                TextField(L10n.string("todo.tag.name_placeholder"), text: $renameText)
                Button("common.cancel", role: .cancel) { renamingTag = nil }
                Button("common.save") { commitRename() }
            } message: {
                Text("todo.tag.name_placeholder")
            }
            .alert(
                errorMessage ?? "",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            }
            .confirmationDialog(
                Text("todo.tag.delete_confirm_title"),
                isPresented: $showsDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("common.delete", role: .destructive) { commitDelete() }
                Button("common.cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("todo.tag.delete_confirm_message")
            }
        }
    }

    // MARK: - 行

    private func tagRow(_ tag: TodoTag) -> some View {
        let color = CategoryPalette.color(index: Int(tag.colorIndex), scheme: colorScheme)
        let count = ((tag.items as? Set<TodoItem>) ?? []).count

        return HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(tag.name ?? "")
                .font(AppTypography.body)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: AppSpacing.sm)

            if count > 0 {
                Text("\(count)")
                    .font(AppTypography.tiny)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(minHeight: AppLayout.listRowMinHeight)
        .padding(.horizontal, AppSpacing.md)
        .appGlassCard(cornerRadius: AppRadius.row)
        .contentShape(Rectangle())
        .onTapGesture { beginRename(tag) }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("todo.tag.rename"))
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "tag")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("todo.tags.empty")
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.section)
    }

    // MARK: - 重命名 / 删除

    private func beginRename(_ tag: TodoTag) {
        renamingTag = tag
        renameText = tag.name ?? ""
    }

    private func commitRename() {
        guard let tag = renamingTag else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let others = tags.compactMap(\.name).filter { $0 != (tag.name ?? "") }

        switch TodoTagRules.validate(trimmed, existingNames: others) {
        case .empty:
            renamingTag = nil
        case .tooLong:
            errorMessage = L10n.string("todo.tag.error.too_long")
        case .duplicate:
            errorMessage = L10n.string("todo.tag.error.duplicate")
        case .limit:
            errorMessage = L10n.string("todo.tag.error.limit")
        case .valid:
            tag.name = trimmed
            try? viewContext.save()
            HapticManager.shared.success()
            renamingTag = nil
        }
    }

    private func commitDelete() {
        guard let tag = pendingDelete else { return }
        HapticManager.shared.medium()
        viewContext.delete(tag)
        try? viewContext.save()
        pendingDelete = nil
    }
}

#Preview {
    TodoTagManageSheet()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
