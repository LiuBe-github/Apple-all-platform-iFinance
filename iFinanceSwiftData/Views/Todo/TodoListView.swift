//
//  TodoListView.swift
//  iFinanceSwiftData
//
//  待办列表：按「逾期 / 今天 / 未来 7 天 / 以后 / 无日期 / 已完成」固定顺序分组，
//  支持勾选完成（重复规则自动生成下一期）、滑动删除与「清除已完成」。
//  分组与排序全部复用 `TodoGrouping` 纯逻辑，视图内不重复实现规则。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改动请同步另一处。
//

import SwiftUI
import SwiftData

struct TodoListView: View {

    /// 点按行（进入编辑）
    var onSelect: (TodoItem) -> Void

    @Environment(\.modelContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(
        filter: PersistenceController.todoUserPredicate,
        sort: \TodoItem.createdAt,
        order: .reverse,
        animation: .default
    ) private var todos: [TodoItem]

    @State private var showsClearConfirm = false
    /// 已展开子任务的待办（按 todo.id）
    @State private var expandedIDs: Set<UUID> = []

    // MARK: - 行模型

    private struct Row: Identifiable {
        let id: UUID
        let item: TodoItem
        let snapshot: TodoSnapshot
    }

    private struct GroupedSection: Identifiable {
        let group: TodoGroup
        let rows: [Row]

        var id: String { group.rawValue }
    }

    // MARK: - Body

    var body: some View {
        let sections = makeSections()
        let hasCompleted = sections.contains { $0.group == .completed }

        Group {
            if todos.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.rows) { row in
                                rowView(row, in: section.group)
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
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            delete(row.item)
                                        } label: {
                                            Label("common.delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            sectionHeader(section)
                        }
                    }

                    if hasCompleted {
                        Section {
                            Button(role: .destructive) {
                                showsClearConfirm = true
                            } label: {
                                Text("todo.completed.clear")
                                    .font(AppTypography.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .confirmationDialog(
                    Text("todo.completed.clear_confirm_title"),
                    isPresented: $showsClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("todo.completed.clear", role: .destructive) { clearCompleted() }
                    Button("common.cancel", role: .cancel) {}
                } message: {
                    Text("todo.completed.clear_confirm_message")
                }
            }
        }
    }

    // MARK: - 分组

    private func makeSections() -> [GroupedSection] {
        let calendar = Calendar.current
        let now = Date()

        var buckets: [TodoGroup: [Row]] = [:]
        for item in todos {
            let snapshot = snapshot(of: item)
            let row = Row(id: snapshot.id, item: item, snapshot: snapshot)
            buckets[TodoGrouping.group(of: snapshot, now: now, calendar: calendar), default: []].append(row)
        }

        return TodoGroup.allCases.compactMap { group in
            guard let bucket = buckets[group], !bucket.isEmpty else { return nil }

            // 同一 id 只保留第一条（脏数据兜底：避免 Dictionary(uniqueKeysWithValues:) 直接 trap）
            var indexed: [UUID: Row] = [:]
            for row in bucket where indexed[row.id] == nil {
                indexed[row.id] = row
            }

            let order = TodoGrouping.sorted(bucket.map(\.snapshot), in: group, calendar: calendar).map(\.id)
            let rows = order.compactMap { indexed[$0] }
            guard !rows.isEmpty else { return nil }
            return GroupedSection(group: group, rows: rows)
        }
    }

    private func snapshot(of item: TodoItem) -> TodoSnapshot {
        TodoSnapshot(
            id: item.id ?? UUID(),
            title: item.title,
            note: item.note,
            dueDate: item.dueDate,
            priority: item.priority,
            isDone: item.isDone,
            repeatRule: item.repeatRule,
            createdAt: item.createdAt
        )
    }

    // MARK: - 分组标题

    private func sectionHeader(_ section: GroupedSection) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(LocalizedStringKey(section.group.localizedKey))
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(section.group == .overdue ? overdueColor : Color.primary)

            Text("\(section.rows.count)")
                .font(AppTypography.tiny)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer(minLength: 0)
        }
        .textCase(nil)
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - 行

    private func rowView(_ row: Row, in group: TodoGroup) -> some View {
        let item = row.item
        let subtasks = sortedSubtasks(of: item)
        let isExpanded = expandedIDs.contains(row.id)

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Button {
                    toggleDone(item)
                } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isDone ? completedColor : Color.secondary)
                        .frame(width: AppLayout.iconTile, height: AppLayout.iconTile)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.scalePress)
                .accessibilityLabel(Text(LocalizedStringKey(item.isDone ? "todo.group.completed" : "todo.segment.todo")))
                .accessibilityAddTraits(item.isDone ? [.isSelected] : [])

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    titleRow(row)
                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    metaRow(row, in: group)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect(item) }

            // 行内展开子任务：直接勾选，不必进入编辑页
            if isExpanded, !subtasks.isEmpty {
                subtaskList(subtasks, of: item)
            }
        }
        .padding(AppSpacing.md)
        .appGlassCard(cornerRadius: AppRadius.row)
        .accessibilityElement(children: .contain)
    }

    private func titleRow(_ row: Row) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text(row.snapshot.title)
                .font(AppTypography.body)
                .strikethrough(row.item.isDone, color: .secondary)
                .foregroundStyle(row.item.isDone ? Color.secondary : Color.primary)
                .lineLimit(2)

            if !row.item.isDone, row.item.priority != TodoPriority.none {
                priorityBadge(row.item.priority)
            }

            Spacer(minLength: 0)
        }
    }

    private func priorityBadge(_ priority: Int16) -> some View {
        let color = priorityColor(priority)
        return Text(LocalizedStringKey(TodoPriority.localizedKey(priority)))
            .font(AppTypography.tiny.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    @ViewBuilder
    private func metaRow(_ row: Row, in group: TodoGroup) -> some View {
        let item = row.item
        let subtasks = item.subtasks
        let tags = item.tags.sorted { ($0.name ?? "") < ($1.name ?? "") }
        let doneSubtasks = subtasks.filter(\.isDone).count
        let isExpanded = expandedIDs.contains(row.id)

        HStack(spacing: AppSpacing.sm) {
            if let due = item.dueDate {
                dueChip(due, isOverdue: group == .overdue && !item.isDone)
            }

            if item.repeatRule != TodoRepeat.noneRule {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(AppTypography.tiny)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("todo.field.repeat"))
            }

            if !subtasks.isEmpty {
                Button {
                    toggleExpanded(row.id)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        Image(systemName: "checklist")
                        Text("\(doneSubtasks)/\(subtasks.count)")
                            .monospacedDigit()
                    }
                    .font(AppTypography.tiny)
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("todo.field.subtasks"))
                .accessibilityValue(Text("\(doneSubtasks)/\(subtasks.count)"))
            }

            ForEach(tags.prefix(3)) { tag in
                tagChip(tag)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - 子任务（行内展开 / 勾选）

    private func subtaskList(_ subtasks: [TodoSubtask], of item: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Divider().opacity(0.4)

            ForEach(subtasks) { subtask in
                Button {
                    toggleSubtask(subtask, of: item)
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                            .font(AppTypography.secondary)
                            .foregroundStyle(subtask.isDone ? completedColor : Color.secondary)

                        Text(subtask.title)
                            .font(AppTypography.secondary)
                            .strikethrough(subtask.isDone, color: .secondary)
                            .foregroundStyle(subtask.isDone ? Color.secondary : Color.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: AppLayout.iconTile)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(subtask.title))
                .accessibilityValue(Text(LocalizedStringKey(subtask.isDone ? "todo.group.completed" : "todo.segment.todo")))
                .accessibilityAddTraits(subtask.isDone ? [.isSelected] : [])
            }
        }
        .padding(.leading, AppSpacing.xl)
    }

    private func sortedSubtasks(of item: TodoItem) -> [TodoSubtask] {
        item.subtasks.sorted { $0.createdAt < $1.createdAt }
    }

    private func toggleExpanded(_ id: UUID) {
        HapticManager.shared.selectionChanged()
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    /// 行内勾选子任务（不改动父待办的完成状态）
    private func toggleSubtask(_ subtask: TodoSubtask, of item: TodoItem) {
        HapticManager.shared.light()
        subtask.isDone.toggle()
        item.updatedAt = Date()
        item.updatedBy = PersistenceController.currentUserIdentifier
        try? viewContext.save()
    }

    @ViewBuilder
    private func dueChip(_ date: Date, isOverdue: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "calendar")
            if Calendar.current.isDateInToday(date) {
                Text("common.today")
            } else if Calendar.current.isDateInYesterday(date) {
                Text("common.yesterday")
            } else {
                Text(date, format: .dateTime.month(.defaultDigits).day())
            }
        }
        .font(AppTypography.tiny)
        .monospacedDigit()
        .foregroundStyle(isOverdue ? overdueColor : Color.secondary)
    }

    private func tagChip(_ tag: TodoTag) -> some View {
        let color = CategoryPalette.color(index: Int(tag.colorIndex), scheme: colorScheme)
        return Text(tag.name ?? "")
            .font(AppTypography.tiny)
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: - 空态

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "checklist")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("todo.empty")
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
            Text("todo.empty.hint")
                .font(AppTypography.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.section)
    }

    // MARK: - 写库

    /// 勾选 / 取消勾选；重复待办勾选完成后自动生成下一期
    private func toggleDone(_ item: TodoItem) {
        let identifier = PersistenceController.currentUserIdentifier
        HapticManager.shared.light()

        if item.isDone {
            item.isDone = false
            item.completedAt = nil
        } else {
            item.isDone = true
            item.completedAt = Date()
            spawnNextOccurrenceIfNeeded(for: item, identifier: identifier)
        }

        item.updatedAt = Date()
        item.updatedBy = identifier
        try? viewContext.save()
    }

    /// 生成下一期：标题 / 备注 / 优先级 / 重复规则 / 标签沿用，子任务重置为未完成
    private func spawnNextOccurrenceIfNeeded(for item: TodoItem, identifier: String) {
        guard let draft = TodoRecurrence.nextDraft(after: snapshot(of: item)) else { return }

        let next = TodoItem(
            id: draft.id,
            title: draft.title,
            note: draft.note,
            dueDate: draft.dueDate,
            priority: draft.priority,
            isDone: draft.isDone,
            completedAt: nil,
            repeatRule: draft.repeatRule,
            createdAt: draft.createdAt,
            updatedAt: Date(),
            createdBy: identifier,
            updatedBy: identifier
        )
        viewContext.insert(next)
        next.tags = item.tags

        for subtask in item.subtasks {
            let copy = TodoSubtask(title: subtask.title, isDone: false, createdAt: Date())
            viewContext.insert(copy)
            copy.owner = next
        }
    }

    private func delete(_ item: TodoItem) {
        HapticManager.shared.medium()
        viewContext.delete(item)
        try? viewContext.save()
    }

    private func clearCompleted() {
        let completed = todos.filter(\.isDone)
        guard !completed.isEmpty else { return }
        HapticManager.shared.medium()
        completed.forEach { viewContext.delete($0) }
        try? viewContext.save()
    }

    // MARK: - 颜色

    private var overdueColor: Color {
        ChartSeriesStyle.accent(for: .expenditure, scheme: colorScheme)
    }

    private var completedColor: Color {
        ChartSeriesStyle.accent(for: .income, scheme: colorScheme)
    }

    private func priorityColor(_ priority: Int16) -> Color {
        switch priority {
        case TodoPriority.high: return .red
        case TodoPriority.medium: return .orange
        case TodoPriority.low: return .blue
        default: return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        TodoListView { _ in }
    }
    .environment(\.modelContext, PersistenceController.preview.container.viewContext)
}
