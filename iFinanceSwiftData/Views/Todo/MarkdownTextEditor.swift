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
            // 先同步 binding 再让代理的 didChange 跑：代理看到 textView.text == parent.text 时不会重复写
            if text != result.text { text = result.text }
            HapticManager.shared.light()
            // 不能在本轮更新里改状态，异步清空指令
            DispatchQueue.main.async { pendingCommand = nil }
            return
        }

        // 正在输入时**绝不**把 binding 里的文本灌回 UITextView：
        // 中文 / 日文输入法在组合（marked text）过程中，binding 往往落后一两个字符，
        // 一旦这里重新赋值就会打断输入法组合、清掉候选，表现为「打字非常卡」。
        // 非编辑态（例如刚打开 sheet 载入内容）才需要同步。
        guard !uiView.isFirstResponder else { return }

        if uiView.text != text {
            uiView.text = text
            uiView.selectedRange = NSRange(location: 0, length: 0)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor

        init(parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let current = textView.text ?? ""
            if parent.text != current { parent.text = current }
        }

        /// 输入法组合结束 / 失焦时再补一次同步，避免最后一次组合内容没写回
        func textViewDidEndEditing(_ textView: UITextView) {
            let current = textView.text ?? ""
            if parent.text != current { parent.text = current }
        }
    }
}
