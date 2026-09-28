//
//  MemoMarkdownTests.swift
//  iFinanceTests
//
//  备忘 Markdown 纯逻辑回归：快捷语法（选区包裹 / 去包裹 / 行首前缀切换）与渲染结果。
//

import XCTest
import Foundation
@testable import iFinance

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
        let blocks = MemoMarkdownRenderer.blocks(from: "这是 **重点** 和 `代码`")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(String(blocks[0].content.characters), "这是 重点 和 代码")

        let boldRun = blocks[0].content.runs.first { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        XCTAssertNotNil(boldRun, "粗体应保留为行内语义属性")
    }

    func testRendererConvertsBlockPrefixes() {
        let heading = MemoMarkdownRenderer.blocks(from: "# 标题")
        XCTAssertEqual(heading.first?.style, .heading(level: 1))
        XCTAssertEqual(plainText(of: heading.first), "标题")
        XCTAssertNil(heading.first?.symbol)

        let unchecked = MemoMarkdownRenderer.blocks(from: "- [ ] 未完成").first
        XCTAssertEqual(unchecked?.symbol, "☐")
        XCTAssertEqual(unchecked?.isChecked, false)
        XCTAssertEqual(plainText(of: unchecked), "未完成")

        let checked = MemoMarkdownRenderer.blocks(from: "- [x] 已完成").first
        XCTAssertEqual(checked?.symbol, "☑")
        XCTAssertEqual(checked?.isChecked, true)

        let bullet = MemoMarkdownRenderer.blocks(from: "- 列表项").first
        XCTAssertEqual(bullet?.symbol, "•")
        XCTAssertEqual(plainText(of: bullet), "列表项")

        let quote = MemoMarkdownRenderer.blocks(from: "> 引用").first
        XCTAssertEqual(quote?.symbol, "▎")
    }

    /// 取块内纯文本（去掉行内标记）
    private func plainText(of block: MemoMarkdownBlock?) -> String {
        guard let block else { return "" }
        return String(block.content.characters)
    }

    func testBlocksKeepLineOrder() {
        let blocks = MemoMarkdownRenderer.blocks(from: "第一行\n- 第二行")
        XCTAssertEqual(blocks.map(\.id), [0, 1])
        XCTAssertEqual(blocks[0].style, .plain)
        XCTAssertEqual(blocks[1].style, .bullet)
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

    // MARK: - 一次性格式指令闸门（修「点格式按钮卡死」）

    func testRequestGateAppliesEachRequestOnce() {
        var gate = MemoMarkdownRequestGate()
        let request = MemoMarkdownRequest(command: .bold)

        XCTAssertTrue(gate.shouldApply(request), "首次遇到该请求应放行")
        XCTAssertFalse(gate.shouldApply(request), "同一条请求被 SwiftUI 反复重绘时不能重复套用")

        let another = MemoMarkdownRequest(command: .bold)
        XCTAssertTrue(gate.shouldApply(another), "新请求（新 id）应放行")
    }

    func testRequestGateResetAllowsReapplyingSameRequest() {
        var gate = MemoMarkdownRequestGate()
        let request = MemoMarkdownRequest(command: .bullet)

        XCTAssertTrue(gate.shouldApply(request))
        gate.reset()
        XCTAssertTrue(gate.shouldApply(request))
    }
}
