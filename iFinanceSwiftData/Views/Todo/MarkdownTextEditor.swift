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
    /// 工具栏下发的语法指令，执行后由协调器清空
    @Binding var pendingCommand: MemoMarkdownCommand?
    /// 选区变化回调（UTF-16 偏移，与 `UITextView.selectedRange` 一致）
    var onSelectionChange: (NSRange) -> Void = { _ in }

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

        if let command = pendingCommand {
            let result = MemoMarkdownEditor.apply(
                command,
                to: uiView.text ?? "",
                selection: uiView.selectedRange
            )
            uiView.text = result.text
            uiView.selectedRange = result.selection
            context.coordinator.isApplyingProgrammaticChange = true
            if text != result.text { text = result.text }
            HapticManager.shared.light()
            // 不能在本轮更新里改状态，异步清空指令
            DispatchQueue.main.async { pendingCommand = nil }
            return
        }

        if uiView.text != text {
            let maxLocation = (text as NSString).length
            let location = min(uiView.selectedRange.location, maxLocation)
            uiView.text = text
            uiView.selectedRange = NSRange(location: location, length: 0)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor
        /// 程序性改文本时避免回调里再写一次 binding
        var isApplyingProgrammaticChange = false

        init(parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else {
                isApplyingProgrammaticChange = false
                return
            }
            parent.text = textView.text ?? ""
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.onSelectionChange(textView.selectedRange)
        }
    }
}
