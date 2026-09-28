//
//  MemoMarkdown.swift
//  iFinance
//
//  备忘正文的 Markdown 支持（纯逻辑，便于单测）：
//  ① `MemoMarkdownCommand` + `apply(_:to:selection:)` —— 快捷语法输入（工具栏按钮）；
//  ② `MemoMarkdownRenderer` —— 行级（标题 / 列表 / 勾选框 / 引用）+ 行内（粗体 / 斜体 /
//     删除线 / 行内代码 / 链接）渲染成 `AttributedString`。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation
import SwiftUI

// MARK: - 快捷语法

/// 备忘编辑器工具栏支持的语法
enum MemoMarkdownCommand: String, CaseIterable, Identifiable {
    case bold
    case italic
    case strikethrough
    case code
    case heading
    case bullet
    case checklist
    case quote

    var id: String { rawValue }

    /// 工具栏按钮的 SF Symbol
    var icon: String {
        switch self {
        case .bold: return "bold"
        case .italic: return "italic"
        case .strikethrough: return "strikethrough"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .heading: return "textformat.size.larger"
        case .bullet: return "list.bullet"
        case .checklist: return "checklist"
        case .quote: return "text.quote"
        }
    }

    /// 工具栏按钮的本地化 key
    var titleKey: String { "memo.toolbar.\(rawValue)" }

    /// 行内语法（包裹选区）；其余为行首语法
    var isInline: Bool {
        switch self {
        case .bold, .italic, .strikethrough, .code: return true
        case .heading, .bullet, .checklist, .quote: return false
        }
    }
}

/// 应用一条快捷语法前后的文本与选区
struct MemoMarkdownEditResult: Equatable {
    let text: String
    /// UTF-16 偏移（与 UITextView.selectedRange 一致）
    let selection: NSRange
}

enum MemoMarkdownEditor {

    /// 行首前缀（列表 / 勾选框 / 引用）
    static let bulletPrefix = "- "
    static let checklistPrefix = "- [ ] "
    static let quotePrefix = "> "

    static func wrapToken(for command: MemoMarkdownCommand) -> String? {
        switch command {
        case .bold: return "**"
        case .italic: return "*"
        case .strikethrough: return "~~"
        case .code: return "`"
        default: return nil
        }
    }

    static func linePrefix(for command: MemoMarkdownCommand) -> String? {
        switch command {
        case .heading: return "# "
        case .bullet: return bulletPrefix
        case .checklist: return checklistPrefix
        case .quote: return quotePrefix
        default: return nil
        }
    }

    /// 应用一条语法：行内语法包裹 / 取消包裹选区；行首语法为「选中的每一行」加 / 去前缀。
    static func apply(
        _ command: MemoMarkdownCommand,
        to text: String,
        selection: NSRange
    ) -> MemoMarkdownEditResult {
        let ns = text as NSString
        let safeRange = clamp(selection, in: ns)

        if let token = wrapToken(for: command) {
            return applyInline(token: token, to: text, selection: safeRange, ns: ns)
        }
        if let prefix = linePrefix(for: command) {
            return applyLinePrefix(prefix, to: text, selection: safeRange, ns: ns)
        }
        return MemoMarkdownEditResult(text: text, selection: safeRange)
    }

    // MARK: 行内

    private static func applyInline(
        token: String,
        to text: String,
        selection: NSRange,
        ns: NSString
    ) -> MemoMarkdownEditResult {
        let tokenLength = (token as NSString).length

        // 选区两侧已有 token → 取消包裹
        let beforeStart = selection.location - tokenLength
        let afterEnd = selection.location + selection.length
        if beforeStart >= 0,
           afterEnd + tokenLength <= ns.length,
           ns.substring(with: NSRange(location: beforeStart, length: tokenLength)) == token,
           ns.substring(with: NSRange(location: afterEnd, length: tokenLength)) == token {
            let inner = ns.substring(with: selection)
            let replaced = ns.replacingCharacters(in: NSRange(location: beforeStart, length: tokenLength * 2 + selection.length), with: inner)
            return MemoMarkdownEditResult(
                text: replaced,
                selection: NSRange(location: beforeStart, length: selection.length)
            )
        }

        let selectedText = ns.substring(with: selection)
        let replacement = token + selectedText + token
        let newText = ns.replacingCharacters(in: selection, with: replacement)

        // 有选区时保持选中原文，无选区时把光标放到两个 token 中间
        let newSelection = selection.length > 0
            ? NSRange(location: selection.location + tokenLength, length: selection.length)
            : NSRange(location: selection.location + tokenLength, length: 0)

        return MemoMarkdownEditResult(text: newText, selection: newSelection)
    }

    // MARK: 行首

    private static func applyLinePrefix(
        _ prefix: String,
        to text: String,
        selection: NSRange,
        ns: NSString
    ) -> MemoMarkdownEditResult {
        let lineRange = ns.lineRange(for: selection)
        let block = ns.substring(with: lineRange)
        let hasTrailingNewline = block.hasSuffix("\n")
        let body = hasTrailingNewline ? String(block.dropLast()) : block
        var lines = body.components(separatedBy: "\n")

        let allPrefixed = lines.allSatisfy { line in
            line.isEmpty || line.hasPrefix(prefix)
        }

        if allPrefixed {
            lines = lines.map { line in
                guard line.hasPrefix(prefix) else { return line }
                return String(line.dropFirst(prefix.count))
            }
        } else {
            lines = lines.map { line in
                line.hasPrefix(prefix) ? line : prefix + line
            }
        }

        // 勾选框：加前缀时同时规范化成未勾选
        var newBlock = lines.joined(separator: "\n")
        if hasTrailingNewline { newBlock += "\n" }

        let newText = ns.replacingCharacters(in: lineRange, with: newBlock)
        let delta = (newBlock as NSString).length - (block as NSString).length
        let newSelection = NSRange(
            location: max(0, selection.location),
            length: max(0, selection.length + delta)
        )
        return MemoMarkdownEditResult(text: newText, selection: newSelection)
    }

    private static func clamp(_ range: NSRange, in ns: NSString) -> NSRange {
        let location = min(max(0, range.location), ns.length)
        let length = min(max(0, range.length), ns.length - location)
        return NSRange(location: location, length: length)
    }
}

// MARK: - 渲染

enum MemoMarkdownRenderer {

    /// 行级语法类型
    enum LineStyle: Equatable {
        case plain
        case heading(level: Int)
        case bullet
        case checklist(done: Bool)
        case quote
    }

    /// 解析单行的行级语法，返回样式与去掉前缀后的正文
    static func parse(_ line: String) -> (style: LineStyle, content: String) {
        let trimmedLeading = line.drop { $0 == " " || $0 == "\t" }
        let indent = String(line.prefix(line.count - trimmedLeading.count))

        if trimmedLeading.hasPrefix("# ") {
            return (.heading(level: 1), indent + String(trimmedLeading.dropFirst(2)))
        }
        if trimmedLeading.hasPrefix("## ") {
            return (.heading(level: 2), indent + String(trimmedLeading.dropFirst(3)))
        }
        if trimmedLeading.hasPrefix("### ") {
            return (.heading(level: 3), indent + String(trimmedLeading.dropFirst(4)))
        }
        for marker in ["- [ ] ", "* [ ] ", "- [x] ", "- [X] "] {
            if trimmedLeading.hasPrefix(marker) {
                let done = marker.contains("x") || marker.contains("X")
                return (.checklist(done: done), indent + String(trimmedLeading.dropFirst(marker.count)))
            }
        }
        for marker in ["- ", "* ", "+ "] {
            if trimmedLeading.hasPrefix(marker) {
                return (.bullet, indent + String(trimmedLeading.dropFirst(marker.count)))
            }
        }
        if trimmedLeading.hasPrefix("> ") {
            return (.quote, indent + String(trimmedLeading.dropFirst(2)))
        }
        return (.plain, line)
    }

    /// 把 Markdown 源文本渲染成 `AttributedString`（行级前缀转成符号，行内语法交给系统解析）
    static func attributedString(from source: String) -> AttributedString {
        guard !source.isEmpty else { return AttributedString() }

        var output = AttributedString()
        let lines = source.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let (style, content) = parse(line)
            var rendered = inline(content)

            switch style {
            case .plain:
                break
            case .heading(let level):
                let font: Font = level == 1
                    ? .title3.bold()
                    : (level == 2 ? .headline : .subheadline.weight(.semibold))
                rendered.font = font
            case .bullet:
                var bullet = AttributedString("•  ")
                bullet.foregroundColor = .secondary
                rendered = bullet + rendered
            case .checklist(let done):
                var box = AttributedString(done ? "☑  " : "☐  ")
                box.foregroundColor = done ? .secondary : .accentColor
                var body = rendered
                if done {
                    body.strikethroughStyle = .single
                    body.foregroundColor = .secondary
                }
                rendered = box + body
            case .quote:
                var bar = AttributedString("▎ ")
                bar.foregroundColor = .secondary
                rendered = bar + rendered
            }

            output += rendered
            if index < lines.count - 1 {
                output += AttributedString("\n")
            }
        }
        return output
    }

    /// 列表 / 详情里的一行纯文本预览（去掉 Markdown 标记）
    static func plainPreview(from source: String, lineLimit: Int = 1) -> String {
        let lines = source
            .components(separatedBy: "\n")
            .map { parse($0).content.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return "" }
        let joined = lines.prefix(max(1, lineLimit)).joined(separator: " ")
        // 顺带去掉行内标记（** / ~~ / ` 等）
        return String(inline(joined).characters)
    }

    /// 行内语法解析（粗体 / 斜体 / 删除线 / 行内代码 / 链接）；失败时回退原文
    private static func inline(_ text: String) -> AttributedString {
        guard !text.isEmpty else { return AttributedString() }

        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        if let parsed = try? AttributedString(markdown: text, options: options) {
            return parsed
        }
        return AttributedString(text)
    }
}
