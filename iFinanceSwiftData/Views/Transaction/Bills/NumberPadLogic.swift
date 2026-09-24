//
//  NumberPadLogic.swift
//  iFinance
//
//  数字键盘的表达式编辑逻辑（纯函数，便于单测）：
//  - 数字 / 小数点按「当前数字段」（最后一个运算符之后的部分）校验，而不是整串表达式
//  - 运算符按钮第一次按下插入主运算符，再按一次切换为备用运算符
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation

enum NumberPadExpression {
    /// 空表达式占位
    static let placeholder = "0.00"
    /// 支持的运算符
    static let operators: Set<Character> = ["+", "-", "×", "÷"]
    /// 单个数字的最大整数位
    static let maxIntegerDigits = 9
    /// 单个数字的最大小数位
    static let maxFractionDigits = 2

    /// 当前正在输入的数字段（最后一个运算符之后的部分）
    static func currentSegment(of text: String) -> String {
        guard let lastOperatorIndex = text.lastIndex(where: { operators.contains($0) }) else {
            return text
        }
        return String(text[text.index(after: lastOperatorIndex)...])
    }

    /// 追加数字或小数点
    static func append(_ input: String, to text: String) -> String {
        guard !input.isEmpty else { return text }

        // 初始占位状态：直接以新输入开始
        if text == placeholder {
            return input == "." ? "0." : input
        }

        let segment = currentSegment(of: text)

        if input == "." {
            // 当前数字已经带小数点 → 忽略；运算符后直接按小数点 → 补 0.
            guard !segment.contains(".") else { return text }
            return text + (segment.isEmpty ? "0." : ".")
        }

        // 数字：避免前导 0（0 → 输入 5 得 5，而不是 05）
        if segment == "0" {
            return String(text.dropLast()) + input
        }

        if let dotIndex = segment.firstIndex(of: ".") {
            // 小数位上限
            let fraction = segment[segment.index(after: dotIndex)...]
            guard fraction.count < maxFractionDigits else { return text }
        } else {
            // 整数位上限
            guard segment.count < maxIntegerDigits else { return text }
        }

        return text + input
    }

    /// 按下运算符按钮：末尾没有运算符则插入主运算符，已有则在本按钮的两个运算符之间切换
    static func applyOperator(primary: String, alternate: String, to text: String) -> String {
        guard text != placeholder else { return text }
        guard let last = text.last, operators.contains(last) else {
            return text + primary
        }
        let replacement = (String(last) == primary) ? alternate : primary
        return String(text.dropLast()) + replacement
    }

    /// 退格
    static func deleteLast(from text: String) -> String {
        guard text != placeholder else { return placeholder }
        if text.count <= 1 { return placeholder }
        return String(text.dropLast())
    }

    /// 百分比：把当前数字除以 100（表达式含运算符时不处理）
    static func applyPercent(to text: String) -> String {
        guard let value = Double(text), value != 0 else { return text }
        return String(format: "%.2f", value / 100)
    }
}
