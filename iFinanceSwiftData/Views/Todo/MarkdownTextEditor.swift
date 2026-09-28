//
//  MarkdownTextEditor.swift
//  iFinance
//
//  备忘正文编辑器：SwiftUI 的 `TextEditor` 不暴露选区，无法把「粗体 / 列表」等语法
//  精确作用在选中的文字上，所以这里用 `UITextView` 包一层，提供：
//  ① 选区回传（供工具栏判断可用状态）；
//  ② 待执行语法指令（`pendingCommand`），由协调器在选区上就地插入 / 包裹 / 去前缀。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI
import UIKit

struct MarkdownTextEditor: UIViewRepresentable {

    @Binding var text: String
    /// 工具栏下发的一次性格式指令（同一 `id` 只会应用一次）
    @Binding var request: MemoMarkdownRequest?
    /// 是否正在输入法组合（候选栏显示中）：由编辑器回传，供工具栏置灰
    @Binding var isComposing: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(
            top: AppSpacing.md,
            left: AppSpacing.sm,
            bottom: AppSpacing.md,
            right: AppSpacing.sm
        )
        view.text = text
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        // ① 一次性格式指令：同一 id 只应用一次（重绘多少次都不会重复套用）
        if let request, context.coordinator.gate.shouldApply(request) {
            apply(request.command, to: uiView, coordinator: context.coordinator)
            DispatchQueue.main.async {
                // 只有还是同一条请求时才清空，避免把用户新点的指令吞掉
                if self.request?.id == request.id { self.request = nil }
            }
            return
        }

        // ② 正在输入时**绝不**把 binding 里的文本灌回 UITextView：
        // 中文 / 日文输入法在组合（marked text）过程中，binding 往往落后一两个字符，
        // 一旦这里重新赋值就会打断输入法组合、清掉候选，表现为「打字非常卡」。
        // 非编辑态（例如刚打开 sheet 载入内容）才需要同步。
        guard !uiView.isFirstResponder else { return }

        if uiView.text != text {
            uiView.text = text
            uiView.selectedRange = NSRange(location: 0, length: 0)
        }
    }

    /// 把一条格式指令作用到当前选区；副作用（触觉反馈）由按钮负责，这里只改文本
    private func apply(
        _ command: MemoMarkdownCommand,
        to uiView: UITextView,
        coordinator: Coordinator
    ) {
        // 兜底：万一指令到达时还在拼字（按钮已置灰，理论上不会），先提交当前候选再套格式，避免丢字
        if uiView.markedTextRange != nil {
            uiView.unmarkText()
        }

        let result = MemoMarkdownEditor.apply(
            command,
            to: uiView.text ?? "",
            selection: uiView.selectedRange
        )
        uiView.text = result.text
        uiView.selectedRange = result.selection
        if text != result.text { text = result.text }
        coordinator.syncComposingState(uiView)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor
        /// 一次性指令闸门
        var gate = MemoMarkdownRequestGate()

        init(parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            syncComposingState(textView)
            let current = textView.text ?? ""
            if parent.text != current { parent.text = current }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            syncComposingState(textView)
        }

        /// 输入法组合结束 / 失焦时再补一次同步，避免最后一次组合内容没写回
        func textViewDidEndEditing(_ textView: UITextView) {
            syncComposingState(textView)
            let current = textView.text ?? ""
            if parent.text != current { parent.text = current }
        }

        /// 只在「组合开始 / 结束」时更新 binding，避免每次按键都触发整页重绘
        func syncComposingState(_ textView: UITextView) {
            let composing = textView.markedTextRange != nil
            if parent.isComposing != composing {
                parent.isComposing = composing
            }
        }
    }
}
