//
//  BillEditRules.swift
//  iFinance
//
//  编辑账单的类型 / 分类联动规则（纯函数，便于单测）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation

enum BillEditRules {
    /// 转账类型
    static let transferType = "transfer"
    /// 转账账单固定的分类值
    static let transferCategory = "transfer"

    /// 归一化账单类型：把历史数据里的中文类型（模型默认值「支出」等）映射回规范字符串。
    /// 旧版本 / 异常写入的账单可能带着 `支出` / `收入` / `转账`，若直接用它们初始化编辑页，
    /// 类型分段控件没有对应 tag、`CategoryKind(billType:)` 也解析不出来，
    /// 结果是**保存按钮永远禁用**——用户改完金额点保存毫无反应（金额也就没写进库）。
    static func normalizedType(_ raw: String?) -> String {
        switch raw {
        case "income", "收入": return "income"
        case "transfer", "转账": return "transfer"
        case "expenditure", "支出": return "expenditure"
        default: return "expenditure"
        }
    }

    /// 切换类型后分类的初始值：转账固定为 transfer，支出/收入清空（要求重新选择）
    static func categoryAfterTypeChange(to type: String) -> String? {
        type == transferType ? transferCategory : nil
    }

    /// 分类是否属于指定类型（支持自定义分类与「父/子」二级路径）
    @MainActor
    static func isValid(_ category: String?, for type: String) -> Bool {
        guard let category, !category.isEmpty else { return false }

        if type == transferType {
            return category == transferCategory
        }
        guard let kind = CategoryKind(billType: type) else { return false }
        return CategoryResolver.isValid(category, kind: kind)
    }

    /// 打开已有账单时归一化分类：不匹配类型（历史脏数据）按「未选择」处理；转账一律归为 transfer
    @MainActor
    static func normalizedCategory(_ category: String?, for type: String) -> String? {
        if type == transferType { return transferCategory }
        return isValid(category, for: type) ? category : nil
    }
}

/// 金额输入归一化：把全角数字 / 全角小数点 / 中文句号 / 逗号千分位统一成半角，
/// 避免第三方输入法或全角键盘输入的字被过滤掉（表现为「改了金额其实没输进去」）。
enum BillAmountInput {

    static func normalize(_ raw: String) -> String {
        var output = ""
        for scalar in raw.unicodeScalars {
            switch scalar {
            case "0"..."9":
                output.unicodeScalars.append(scalar)
            case "０"..."９":
                // 全角数字 → 半角
                if let half = Unicode.Scalar(scalar.value - 0xFEE0) {
                    output.unicodeScalars.append(half)
                }
            case ".", "．", "。":
                output.append(".")
            case "，", ",":
                continue    // 千分位直接丢掉
            case "－", "—":
                output.append("-")
            default:
                continue
            }
        }
        // 只允许一个小数点
        let parts = output.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count > 2 {
            output = parts[0] + "." + parts.dropFirst().joined()
        }
        return output
    }

    static func value(_ raw: String) -> Double? {
        let normalized = normalize(raw)
        guard !normalized.isEmpty, normalized != "-" else { return nil }
        return Double(normalized)
    }
}
