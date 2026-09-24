//
//  BillEditRules.swift
//  iFinanceSwiftData
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

    /// 切换类型后分类的初始值：转账固定为 transfer，支出/收入清空（要求重新选择）
    static func categoryAfterTypeChange(to type: String) -> String? {
        type == transferType ? transferCategory : nil
    }

    /// 分类是否属于指定类型
    static func isValid(_ category: String?, for type: String) -> Bool {
        guard let category, !category.isEmpty else { return false }

        if type == transferType {
            return category == transferCategory
        }
        if ExpenditureCategory(rawValue: category) != nil {
            return type == "expenditure"
        }
        if IncomeCategory(rawValue: category) != nil {
            return type == "income"
        }
        return false
    }

    /// 打开已有账单时归一化分类：不匹配类型（历史脏数据）按「未选择」处理；转账一律归为 transfer
    static func normalizedCategory(_ category: String?, for type: String) -> String? {
        if type == transferType { return transferCategory }
        return isValid(category, for: type) ? category : nil
    }
}

