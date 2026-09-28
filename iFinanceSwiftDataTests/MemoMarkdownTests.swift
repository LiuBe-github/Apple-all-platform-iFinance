//
//  MemoMarkdownTests.swift
//  iFinanceTests
//
//  备忘 Markdown 纯逻辑回归：快捷语法（选区包裹 / 去包裹 / 行首前缀切换）与渲染结果。
//

import XCTest
import Foundation
@testable import iFinanceSwiftData

final class MemoMarkdownTests: XCTestCase {

    // MARK: - 快捷语法：行内

    func testBoldWrapsSelection() {
        let result = MemoMarkdownEditor.apply(.bold, to: "hello", selection: NSRange(location: 0, length: 5))
        XCTAssertEqual(result.text, "**hello**")
        XCTAssertEqual(result.selection, NSRange(location: 2, length: 5), "包裹后仍应选中原文")
    }

    func testBoldTogglesOffWhenAlreadyWrapped() {
        let once = MemoMarkdownEditor.apply(.bold, to: "hello", selection: NSRange(location: 0, length: 5))
        let twice = MemoMarkdownEditor.apply(.bold, to: once.text, selection: once.selection)
        XCTAssertEqual(twice.text, "hello")
        XCTAssertEqual(twice.selection, NSRange(location: 0, length: 5))
    }

    func testInlineCommandWithoutSelectionInsertsPair() {
        // 光标在 "abc" 的第 1 位（UTF-16），插入成对标记后光标落在中间
        let result = MemoMarkdownEditor.apply(.italic, to: "abc", selection: NSRange(location: 1, length: 0))
        XCTAssertEqual(result.text, "a**bc")
        XCTAssertEqual(result.selection, NSRange(location: 2, length: 0))
    }

    func testStrikethroughAndCodeTokens() {
        let strike = MemoMarkdownEditor.apply(.strikethrough, to: "x", selection: NSRange(location: 0, length: 1))
        XCTAssertEqual(strike.text, "~~x~~")

        let code = MemoMarkdownEditor.apply(.code, to: "let a = 1", selection: NSRange(location: 0, length: 9))
        XCTAssertEqual(code.text, "`let a = 1`")
    }

    // MARK: - 快捷语法：行首

    func testBulletPrefixAppliesToEverySelectedLine() {
        let text = "第一行\n第二行"
        let result = MemoMarkdownEditor.apply(.bullet, to: text, selection: NSRange(location: 0, length: (text as NSString).length))
        XCTAssertEqual(result.text, "- 第一行\n- 第二行")
    }

    func testBulletPrefixTogglesOff() {
        let once = MemoMarkdownEditor.apply(.bullet, to: "第一行", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(once.text, "- 第一行")

        let twice = MemoMarkdownEditor.apply(.bullet, to: once.text, selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(twice.text, "第一行")
    }

    func testChecklistAndHeadingAndQuotePrefixes() {
        let checklist = MemoMarkdownEditor.apply(.checklist, to: "买牛奶", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(checklist.text, "- [ ] 买牛奶")

        let heading = MemoMarkdownEditor.apply(.heading, to: "本周计划", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(heading.text, "# 本周计划")

        let quote = MemoMarkdownEditor.apply(.quote, to: "引用内容", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(quote.text, "> 引用内容")
    }

    // MARK: - 渲染

    func testRendererStripsInlineMarkers() {
        let rendered = MemoMarkdownRenderer.attributedString(from: "这是 **重点** 和 `代码`")
        XCTAssertEqual(String(rendered.characters), "这是 重点 和 代码")

        let boldRun = rendered.runs.first { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        XCTAssertNotNil(boldRun, "粗体应保留为行内语义属性")
    }

    func testRendererConvertsBlockPrefixes() {
        XCTAssertEqual(
            String(MemoMarkdownRenderer.attributedString(from: "# 标题").characters),
            "标题"
        )
        XCTAssertEqual(
            String(MemoMarkdownRenderer.attributedString(from: "- [ ] 未完成").characters),
            "☐  未完成"
        )
        XCTAssertEqual(
            String(MemoMarkdownRenderer.attributedString(from: "- [x] 已完成").characters),
            "☑  已完成"
        )
        XCTAssertEqual(
            String(MemoMarkdownRenderer.attributedString(from: "- 列表项").characters),
            "•  列表项"
        )
    }

    func testPlainPreviewRemovesAllMarkers() {
        let preview = MemoMarkdownRenderer.plainPreview(from: "# 标题\n- [ ] **任务**\n> 引用", lineLimit: 3)
        XCTAssertEqual(preview, "标题 任务 引用")
    }

    func testParseLineStyle() {
        XCTAssertEqual(MemoMarkdownRenderer.parse("## 二级").style, .heading(level: 2))
        XCTAssertEqual(MemoMarkdownRenderer.parse("- [x] 完成").style, .checklist(done: true))
        XCTAssertEqual(MemoMarkdownRenderer.parse("- 项目").style, .bullet)
        XCTAssertEqual(MemoMarkdownRenderer.parse("> 引用").style, .quote)
        XCTAssertEqual(MemoMarkdownRenderer.parse("普通文本").style, .plain)
    }
}
