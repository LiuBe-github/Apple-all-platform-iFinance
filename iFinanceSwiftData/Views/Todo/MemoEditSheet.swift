//
//  MemoEditSheet.swift
//  iFinanceSwiftData
//
//  备忘新建 / 编辑 sheet：标题（可选）+ 正文；标题与正文不能同时为空。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改动请同步另一处。
//

import SwiftUI
import SwiftData

struct MemoEditSheet: View {

    /// 传 nil 表示新建
    let note: MemoNote?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var viewContext

    @State private var title = ""
    @State private var content = ""
    @State private var errorMessage: String?
    @State private var showsDeleteConfirm = false
    @State private var showsMarkdownPreview = false
    @State private var pendingCommand: MemoMarkdownCommand?
    @State private var editorSelection = NSRange(location: 0, length: 0)

    private var isEditing: Bool { note != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        sectionBlock("memo.field.title") {
                            TextField(L10n.string("memo.field.title"), text: $title)
                                .textFieldStyle(.plain)
                                .padding(AppSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                        }

                        sectionBlock("memo.field.content") {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                markdownModePicker

                                if showsMarkdownPreview {
                                    markdownPreview
                                } else {
                                    MarkdownTextEditor(
                                        text: $content,
                                        pendingCommand: $pendingCommand,
                                        onSelectionChange: { editorSelection = $0 }
                                    )
                                    .frame(minHeight: AppLayout.editorMinHeight)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                                            .fill(Color(UIColor.secondarySystemBackground))
                                    )
                                    .overlay(alignment: .topLeading) {
                                        if content.isEmpty {
                                            Text("memo.field.content_placeholder")
                                                .font(AppTypography.secondary)
                                                .foregroundStyle(.tertiary)
                                                .padding(.horizontal, AppSpacing.md)
                                                .padding(.vertical, AppSpacing.lg)
                                                .allowsHitTesting(false)
                                        }
                                    }

                                    markdownToolbar
                                }
                            }
                        }

                        if isEditing {
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
                    }
                    .padding(AppSpacing.lg)
                    .appContentWidth(AppLayout.formMaxWidth)
                }
            }
            .navigationTitle(L10n.string(isEditing ? "memo.edit" : "memo.add"))
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
            .confirmationDialog(
                Text("common.delete"),
                isPresented: $showsDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("common.delete", role: .destructive) { deleteNote() }
                Button("common.cancel", role: .cancel) {}
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

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

    // MARK: - Markdown（快捷语法 + 预览）

    private var markdownModePicker: some View {
        Picker("", selection: $showsMarkdownPreview) {
            Text("memo.markdown.edit").tag(false)
            Text("memo.markdown.preview").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .appAnimation(AppMotion.quick, value: showsMarkdownPreview)
    }

    /// 快捷语法工具栏：把语法作用在当前选区上（无选区时插入成对标记并把光标置于中间）
    private var markdownToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(MemoMarkdownCommand.allCases) { command in
                    Button {
                        pendingCommand = command
                    } label: {
                        Image(systemName: command.icon)
                            .font(AppTypography.secondary)
                            .foregroundStyle(.primary)
                            .frame(width: AppLayout.iconTile, height: AppLayout.iconTile)
                            .background(
                                Circle().fill(Color(UIColor.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.scalePress)
                    .accessibilityLabel(Text(LocalizedStringKey(command.titleKey)))
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var markdownPreview: some View {
        ScrollView {
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("memo.markdown.empty")
                    .font(AppTypography.secondary)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
            } else {
                Text(MemoMarkdownRenderer.attributedString(from: content))
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .textSelection(.enabled)
            }
        }
        .frame(minHeight: AppLayout.editorMinHeight)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    // MARK: - 加载 / 保存

    private func loadIfNeeded() {
        guard let note, title.isEmpty, content.isEmpty else { return }
        title = note.title ?? ""
        content = note.content ?? ""
        // 打开已有备忘默认进「预览」（阅读），新建时留在「编辑」
        showsMarkdownPreview = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else {
            errorMessage = L10n.string("memo.error.empty")
            return
        }

        let identifier = PersistenceController.currentUserIdentifier
        let target: MemoNote
        if let note {
            target = note
        } else {
            let created = MemoNote(createdBy: identifier, updatedBy: identifier)
            viewContext.insert(created)
            target = created
        }

        target.title = trimmedTitle.isEmpty ? nil : trimmedTitle
        target.content = trimmedContent.isEmpty ? nil : trimmedContent
        target.updatedAt = Date()
        target.updatedBy = identifier

        try? viewContext.save()
        HapticManager.shared.success()
        dismiss()
    }

    private func deleteNote() {
        guard let note else { return }
        HapticManager.shared.medium()
        viewContext.delete(note)
        try? viewContext.save()
        dismiss()
    }
}

#Preview {
    MemoEditSheet(note: nil)
        .environment(\.modelContext, PersistenceController.preview.container.viewContext)
}
