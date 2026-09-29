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
    /// 只在切入预览时解析，避免 SwiftUI body 重算时反复解析整篇 Markdown。
    @State private var markdownPreviewBlocks: [MemoMarkdownBlock] = []
    @State private var markdownRequest: MemoMarkdownRequest?
    /// 输入法是否正在组合（候选栏显示中）：组合期间格式按钮置灰
    @State private var isComposing = false

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
                                        request: $markdownRequest,
                                        isComposing: $isComposing
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
            .onChange(of: showsMarkdownPreview) { _, showsPreview in
                if showsPreview { rebuildMarkdownPreview() }
            }
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

    /// 快捷语法工具栏：把语法作用在当前选区上（无选区时插入成对标记并把光标置于中间）。
    /// 输入法正在拼字（候选栏显示中）时按钮置灰——此阶段改写文本会打断输入法组合。
    private var markdownToolbar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(MemoMarkdownCommand.allCases) { command in
                        Button {
                            HapticManager.shared.light()
                            markdownRequest = MemoMarkdownRequest(command: command)
                        } label: {
                            Image(systemName: command.icon)
                                .font(AppTypography.secondary)
                                .foregroundStyle(isComposing ? Color.secondary : Color.primary)
                                .frame(width: AppLayout.iconTile, height: AppLayout.iconTile)
                                .background(
                                    Circle().fill(Color(UIColor.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.scalePress)
                        .disabled(isComposing)
                        .accessibilityLabel(Text(LocalizedStringKey(command.titleKey)))
                    }
                }
                .padding(.vertical, 1)
            }

            if isComposing {
                Text("memo.markdown.composing_hint")
                    .font(AppTypography.tiny)
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
        }
        .appAnimation(AppMotion.quick, value: isComposing)
    }

    /// 预览：逐行渲染（行级样式在视图层设置，避免 `AttributedString` 的 SwiftUI 属性作用域拖慢类型检查）
    private var markdownPreview: some View {
        ScrollView {
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("memo.markdown.empty")
                    .font(AppTypography.secondary)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(markdownPreviewBlocks) { block in
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            if let symbol = block.symbol {
                                Text(symbol)
                                    .font(markdownFont(for: block.style))
                                    .foregroundStyle(.secondary)
                            }

                            markdownInlineText(for: block)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: AppLayout.editorMinHeight)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    /// 显式把 Foundation 的 Markdown 语义映射成 SwiftUI Text 样式。
    /// 不依赖 `Text(AttributedString)` 在外层 `.font` 之后是否仍保留粗体 / 斜体，避免出现“标记消失但样式没渲染”。
    private func markdownInlineText(for block: MemoMarkdownBlock) -> Text {
        let baseFont = markdownFont(for: block.style)

        return block.content.runs.reduce(Text("")) { result, run in
            let attributed = AttributedString(block.content[run.range])
            let intent = run.inlinePresentationIntent
            let font = intent?.contains(.code) == true ? baseFont.monospaced() : baseFont
            var fragment = Text(attributed).font(font)

            if intent?.contains(.stronglyEmphasized) == true { fragment = fragment.bold() }
            if intent?.contains(.emphasized) == true { fragment = fragment.italic() }
            if block.isChecked || intent?.contains(.strikethrough) == true {
                fragment = fragment.strikethrough(color: .secondary)
            }
            if run.link != nil { fragment = fragment.underline() }
            fragment = fragment.foregroundColor(
                block.isChecked ? .secondary : (run.link == nil ? .primary : .accentColor)
            )

            return result + fragment
        }
    }

    /// 行级字体留在视图层，避免纯解析文件引入 SwiftUI 属性作用域拖慢模块编译。
    private func markdownFont(for style: MemoMarkdownLineStyle) -> Font {
        switch style {
        case .heading(let level):
            switch level {
            case 1: return .title3.bold()
            case 2: return .headline
            default: return .subheadline.weight(.semibold)
            }
        case .quote: return AppTypography.secondary
        default: return AppTypography.body
        }
    }

    private func rebuildMarkdownPreview() {
        markdownPreviewBlocks = MemoMarkdownRenderer.blocks(from: content)
    }

    // MARK: - 加载 / 保存

    private func loadIfNeeded() {
        guard let note, title.isEmpty, content.isEmpty else { return }
        title = note.title ?? ""
        content = note.content ?? ""
        // 打开已有备忘默认进「预览」（阅读），新建时留在「编辑」
        showsMarkdownPreview = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if showsMarkdownPreview { rebuildMarkdownPreview() }
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
