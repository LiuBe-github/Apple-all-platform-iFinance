//
//  MemoListView.swift
//  iFinance
//
//  备忘列表：置顶优先、其余按更新时间倒序（`MemoSorting` 纯逻辑），
//  支持滑动置顶 / 删除与点按编辑。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改动请同步另一处。
//

import SwiftUI
internal import CoreData

struct MemoListView: View {

    /// 点按行（进入编辑）
    var onSelect: (MemoNote) -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MemoNote.updatedAt, ascending: false)],
        predicate: PersistenceController.memoUserPredicate,
        animation: .default
    ) private var memos: FetchedResults<MemoNote>

    var body: some View {
        let sorted = makeSortedRows()

        Group {
            if sorted.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sorted) { memo in
                        rowView(memo)
                            .listRowInsets(
                                EdgeInsets(
                                    top: AppSpacing.xs,
                                    leading: AppSpacing.screen,
                                    bottom: AppSpacing.xs,
                                    trailing: AppSpacing.screen
                                )
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    togglePin(memo)
                                } label: {
                                    Label(
                                        (memo.isPinned ?? false) ? "memo.unpin" : "memo.pin",
                                        systemImage: (memo.isPinned ?? false) ? "pin.slash" : "pin"
                                    )
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(memo)
                                } label: {
                                    Label("common.delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: - 排序

    /// 复用 `MemoSorting`（置顶优先 → 更新时间倒序），并保持实体与排序结果一一对应
    private func makeSortedRows() -> [MemoNote] {
        let entries: [(id: UUID, note: MemoNote, isPinned: Bool, updatedAt: Date)] = memos.map {
            (id: $0.id ?? UUID(), note: $0, isPinned: $0.isPinned ?? false, updatedAt: $0.updatedAt ?? .distantPast)
        }

        var indexed: [UUID: MemoNote] = [:]
        for entry in entries where indexed[entry.id] == nil {
            indexed[entry.id] = entry.note
        }

        let order = MemoSorting.sorted(
            entries.map { (id: $0.id, isPinned: $0.isPinned, updatedAt: $0.updatedAt) }
        )
        return order.compactMap { indexed[$0] }
    }

    // MARK: - 行

    private func rowView(_ memo: MemoNote) -> some View {
        let isPinned = memo.isPinned ?? false
        let title = (memo.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let content = (memo.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(title.isEmpty ? firstLine(of: content) : title)
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(AppTypography.tiny)
                        .foregroundStyle(Color.orange)
                        .accessibilityLabel(Text("memo.pin"))
                }
            }

            if !title.isEmpty, !content.isEmpty {
                Text(content)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let updatedAt = memo.updatedAt {
                Text(updatedAt, format: .dateTime.year().month(.defaultDigits).day())
                    .font(AppTypography.tiny)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .appGlassCard(cornerRadius: AppRadius.row)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(memo) }
        .accessibilityElement(children: .combine)
    }

    private func firstLine(of content: String) -> String {
        content.split(whereSeparator: \.isNewline).first.map(String.init) ?? L10n.string("memo.title")
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "note.text")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("memo.empty")
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
            Text("memo.empty.hint")
                .font(AppTypography.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.section)
    }

    // MARK: - 写库

    private func togglePin(_ memo: MemoNote) {
        HapticManager.shared.light()
        memo.isPinned = !(memo.isPinned ?? false)
        memo.updatedBy = PersistenceController.currentUserIdentifier
        try? viewContext.save()
    }

    private func delete(_ memo: MemoNote) {
        HapticManager.shared.medium()
        viewContext.delete(memo)
        try? viewContext.save()
    }
}

#Preview {
    NavigationStack {
        MemoListView { _ in }
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
