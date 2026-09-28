//
//  TodoEditSheet.swift
//  iFinance
//
//  待办新建 / 编辑 sheet：标题、备注、截止日、优先级、重复规则、标签与子任务。
//  标签名规则走 `TodoTagRules` 纯逻辑（1–8 字、不可重名、上限 12 个）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改动请同步另一处。
//

import SwiftUI
internal import CoreData

struct TodoEditSheet: View {

    /// 传 nil 表示新建
    let item: TodoItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TodoTag.name, ascending: true)],
        predicate: PersistenceController.todoTagUserPredicate,
        animation: .default
    ) private var allTags: FetchedResults<TodoTag>

    @State private var title = ""
    @State private var note = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var priority: Int16 = TodoPriority.none
    @State private var repeatRule = TodoRepeat.noneRule
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var subtasks: [SubtaskDraft] = []
    @State private var newSubtaskTitle = ""
    @State private var isTagSheetPresented = false
    @State private var isTagManagePresented = false
    @State private var errorMessage: String?
    @State private var showsDeleteConfirm = false

    /// 子任务草稿：`entity == nil` 表示本次新建（保存时才落库）
    struct SubtaskDraft: Identifiable {
        let id: UUID
        var title: String
        var isDone: Bool
        let entity: TodoSubtask?
    }

    private var isEditing: Bool { item != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        sectionBlock("todo.field.title") { titleField }
                        sectionBlock("todo.field.note") { noteField }
                        sectionBlock("todo.field.due") { dueSection }
                        sectionBlock("todo.field.priority") { priorityPicker }
                        sectionBlock("todo.field.repeat") { repeatPicker }
                        sectionBlock("todo.field.tags") { tagSection }
                        sectionBlock("todo.field.subtasks") { subtaskSection }
                        if isEditing { deleteButton }
                    }
                    .padding(AppSpacing.lg)
                    .appContentWidth(AppLayout.formMaxWidth)
                }
            }
            .navigationTitle(L10n.string(isEditing ? "todo.edit" : "todo.add"))
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
            .sheet(isPresented: $isTagSheetPresented) {
                TodoTagSheet(existingNames: allTags.compactMap(\.name)) { created in
                    selectedTagIDs.insert(created.id ?? UUID())
                }
            }
            .sheet(isPresented: $isTagManagePresented) {
                TodoTagManageSheet()
            }
            .onChange(of: repeatRule) { _, newValue in
                // 重复必须有基准日期，否则「完成后生成下一期」无法计算
                if newValue != TodoRepeat.noneRule { hasDueDate = true }
            }
            .alert(
                errorMessage ?? "",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            }
            .confirmationDialog(
                Text("common.delete"),
                isPresented: $showsDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("common.delete", role: .destructive) { deleteItem() }
                Button("common.cancel", role: .cancel) {}
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    // MARK: - 分块容器

    private func sectionBlock<Content: View>(_ titleKey: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(LocalizedStringKey(titleKey))
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .appCardPadding()
                .appGlassCard()
        }
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
            .fill(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - 标题 / 备注

    private var titleField: some View {
        TextField(L10n.string("todo.field.title_placeholder"), text: $title)
            .textFieldStyle(.plain)
            .padding(AppSpacing.md)
            .background(inputBackground)
    }

    private var noteField: some View {
        TextEditor(text: $note)
            .frame(minHeight: 88)
            .scrollContentBackground(.hidden)
            .padding(AppSpacing.sm)
            .background(inputBackground)
            .overlay(alignment: .topLeading) {
                if note.isEmpty {
                    Text("todo.field.note_placeholder")
                        .font(AppTypography.secondary)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.lg)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - 截止日 / 优先级 / 重复

    private var dueSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Toggle(isOn: $hasDueDate) {
                Label {
                    Text("todo.field.due_toggle")
                        .font(AppTypography.secondary)
                } icon: {
                    Image(systemName: "calendar")
                }
            }
            .tint(ChartSeriesStyle.accent(for: .income, scheme: colorScheme))

            if hasDueDate {
                DatePicker(selection: $dueDate, displayedComponents: [.date, .hourAndMinute]) {
                    Text("todo.field.due")
                        .font(AppTypography.secondary)
                }
                .datePickerStyle(.compact)
            }
        }
    }

    private var priorityPicker: some View {
        Picker("todo.field.priority", selection: $priority) {
            ForEach(TodoPriority.all, id: \.self) { value in
                Text(LocalizedStringKey(TodoPriority.localizedKey(value)))
                    .tag(value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel(Text("todo.field.priority"))
    }

    private var repeatPicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Picker("todo.field.repeat", selection: $repeatRule) {
                ForEach(TodoRepeat.all, id: \.self) { rule in
                    Text(LocalizedStringKey(TodoRepeat.localizedKey(rule)))
                        .tag(rule)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            if repeatRule != TodoRepeat.noneRule {
                Label("todo.repeat.next_hint", systemImage: "arrow.triangle.2.circlepath")
                    .font(AppTypography.tiny)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 标签

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if allTags.isEmpty {
                Text("todo.tags.empty")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(allTags) { tag in
                            tagChip(tag)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            HStack(spacing: AppSpacing.xl) {
                Button {
                    presentTagSheet()
                } label: {
                    Label("todo.tag.add", systemImage: "plus.circle")
                        .font(AppTypography.caption.weight(.semibold))
                }
                .buttonStyle(.scalePress)

                if !allTags.isEmpty {
                    Button {
                        isTagManagePresented = true
                    } label: {
                        Label("todo.tag.manage", systemImage: "slider.horizontal.3")
                            .font(AppTypography.caption.weight(.semibold))
                    }
                    .buttonStyle(.scalePress)
                }
            }
        }
    }

    private func tagChip(_ tag: TodoTag) -> some View {
        let id = tag.id ?? UUID()
        let isSelected = selectedTagIDs.contains(id)
        let color = CategoryPalette.color(index: Int(tag.colorIndex), scheme: colorScheme)

        return Button {
            HapticManager.shared.selectionChanged()
            if isSelected {
                selectedTagIDs.remove(id)
            } else {
                selectedTagIDs.insert(id)
            }
        } label: {
            Text(tag.name ?? "")
                .font(AppTypography.caption)
                .foregroundStyle(isSelected ? color : Color.secondary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(Capsule().fill(color.opacity(isSelected ? 0.20 : 0.08)))
        }
        .buttonStyle(.scalePress)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func presentTagSheet() {
        guard TodoTagRules.canAdd(existingCount: allTags.count) else {
            errorMessage = L10n.string("todo.tag.error.limit")
            return
        }
        isTagSheetPresented = true
    }

    // MARK: - 子任务

    private var subtaskSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach($subtasks) { $draft in
                HStack(spacing: AppSpacing.md) {
                    Button {
                        draft.isDone.toggle()
                        HapticManager.shared.light()
                    } label: {
                        Image(systemName: draft.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundStyle(draft.isDone ? completedColor : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    Text(draft.title)
                        .font(AppTypography.secondary)
                        .strikethrough(draft.isDone, color: .secondary)
                        .foregroundStyle(draft.isDone ? Color.secondary : Color.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Button {
                        removeSubtask(draft)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("common.delete"))
                }
            }

            HStack(spacing: AppSpacing.sm) {
                TextField(L10n.string("todo.subtask.placeholder"), text: $newSubtaskTitle)
                    .textFieldStyle(.plain)
                    .padding(AppSpacing.md)
                    .background(inputBackground)
                    .onSubmit(addSubtask)

                Button("todo.subtask.add") { addSubtask() }
                    .font(AppTypography.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                    .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticManager.shared.light()
        subtasks.append(SubtaskDraft(id: UUID(), title: trimmed, isDone: false, entity: nil))
        newSubtaskTitle = ""
    }

    /// 只改草稿；已删除的实体在保存时统一清理（避免「删除后又取消」把数据删掉）
    private func removeSubtask(_ draft: SubtaskDraft) {
        subtasks.removeAll { $0.id == draft.id }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showsDeleteConfirm = true
        } label: {
            Text("common.delete")
                .font(AppTypography.secondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.scalePress)
        .frame(maxWidth: .infinity)
        .appCardPadding()
        .appGlassCard()
    }

    // MARK: - 加载 / 保存

    private func loadIfNeeded() {
        guard let item, title.isEmpty, subtasks.isEmpty else { return }

        title = item.title ?? ""
        note = item.note ?? ""
        hasDueDate = item.dueDate != nil
        dueDate = item.dueDate ?? Date()
        priority = item.priority
        repeatRule = item.repeatRule ?? TodoRepeat.noneRule
        selectedTagIDs = Set(((item.tags as? Set<TodoTag>) ?? []).compactMap(\.id))
        subtasks = ((item.subtasks as? Set<TodoSubtask>) ?? [])
            .sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
            .map {
                SubtaskDraft(
                    id: $0.id ?? UUID(),
                    title: $0.title ?? "",
                    isDone: $0.isDone,
                    entity: $0
                )
            }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = L10n.string("todo.error.title_empty")
            return
        }

        let identifier = PersistenceController.currentUserIdentifier
        let target: TodoItem
        if let item {
            target = item
        } else {
            let created = TodoItem(context: viewContext)
            created.id = UUID()
            created.createdAt = Date()
            created.createdBy = identifier
            target = created
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.title = trimmedTitle
        target.note = trimmedNote.isEmpty ? nil : trimmedNote
        target.dueDate = hasDueDate ? dueDate : nil
        target.priority = priority
        target.repeatRule = repeatRule
        target.updatedAt = Date()
        target.updatedBy = identifier

        syncTags(to: target)
        syncSubtasks(to: target)

        try? viewContext.save()
        HapticManager.shared.success()
        dismiss()
    }

    private func syncTags(to item: TodoItem) {
        let current = (item.tags as? Set<TodoTag>) ?? []
        for tag in current where !selectedTagIDs.contains(tag.id ?? UUID()) {
            item.removeFromTags(tag)
        }
        for tag in allTags where selectedTagIDs.contains(tag.id ?? UUID()) && !current.contains(tag) {
            item.addToTags(tag)
        }
    }

    private func syncSubtasks(to item: TodoItem) {
        let existing = (item.subtasks as? Set<TodoSubtask>) ?? []
        let keptIDs = Set(subtasks.compactMap { $0.entity?.id })
        for entity in existing where !keptIDs.contains(entity.id ?? UUID()) {
            viewContext.delete(entity)
        }

        for draft in subtasks {
            let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let entity = draft.entity {
                entity.title = trimmed
                entity.isDone = draft.isDone
            } else {
                let created = TodoSubtask(context: viewContext)
                created.id = UUID()
                created.title = trimmed
                created.isDone = draft.isDone
                created.createdAt = Date()
                created.owner = item
            }
        }
    }

    private func deleteItem() {
        guard let item else { return }
        HapticManager.shared.medium()
        viewContext.delete(item)
        try? viewContext.save()
        dismiss()
    }

    private var completedColor: Color {
        ChartSeriesStyle.accent(for: .income, scheme: colorScheme)
    }
}

// MARK: - 新建标签

struct TodoTagSheet: View {

    /// 现有标签名（重名校验）
    var existingNames: [String]
    /// 创建成功回调（调用方负责自动选中）
    var onCreated: (TodoTag) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var name = ""
    @State private var colorIndex = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    TextField(L10n.string("todo.tag.name_placeholder"), text: $name)
                        .textFieldStyle(.plain)
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("todo.field.tags")
                            .font(AppTypography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: AppSpacing.md) {
                            ForEach(0..<8, id: \.self) { index in
                                colorDot(index)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer(minLength: 0)
                }
                .padding(AppSpacing.lg)
                .appContentWidth(AppLayout.formMaxWidth)
            }
            .navigationTitle("todo.tag.add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func colorDot(_ index: Int) -> some View {
        let color = CategoryPalette.color(index: index, scheme: colorScheme)
        return Button {
            HapticManager.shared.selectionChanged()
            colorIndex = index
        } label: {
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
                .overlay {
                    if colorIndex == index {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.scalePress)
        .accessibilityLabel(Text("\(index + 1)"))
        .accessibilityAddTraits(colorIndex == index ? [.isSelected] : [])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch TodoTagRules.validate(trimmed, existingNames: existingNames) {
        case .empty:
            return
        case .tooLong:
            errorMessage = L10n.string("todo.tag.error.too_long")
        case .duplicate:
            errorMessage = L10n.string("todo.tag.error.duplicate")
        case .limit:
            errorMessage = L10n.string("todo.tag.error.limit")
        case .valid:
            let tag = TodoTag(context: viewContext)
            tag.id = UUID()
            tag.name = trimmed
            tag.colorIndex = Int16(colorIndex)
            tag.createdBy = PersistenceController.currentUserIdentifier
            try? viewContext.save()
            HapticManager.shared.success()
            onCreated(tag)
            dismiss()
        }
    }
}

#Preview {
    TodoEditSheet(item: nil)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
