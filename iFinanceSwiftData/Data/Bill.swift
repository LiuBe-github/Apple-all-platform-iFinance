//
//  Bill.swift
//  iFinanceSwiftData
//
//  SwiftData 版账单模型
//  字段与 Core Data 版 Bill 实体一一对应，便于两份数据模型保持同步。
//

import Foundation
import SwiftData

@Model
final class Bill {

    /// 唯一标识（用于幂等写入；与 Core Data 版同语义，可为空）
    var id: UUID?

    /// 金额（对应 Core Data 的 Decimal，可为空）
    var amount: Decimal?

    /// 类型："expenditure" / "income" / "transfer"
    var type: String?

    /// 分类 rawValue（中文字符串）
    var category: String?

    /// 备注
    var note: String?

    /// 记账日期
    var date: Date?

    /// 审计字段
    var createdAt: Date?
    var updatedAt: Date?

    /// 账号隔离键（等于 UserProfile.userIdentifier）
    var createdBy: String?
    var updatedBy: String?

    init(
        id: UUID? = UUID(),
        amount: Decimal? = nil,
        type: String? = nil,
        category: String? = nil,
        note: String? = nil,
        date: Date? = Date(),
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        createdBy: String? = nil,
        updatedBy: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.note = note
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
    }
}

// MARK: - 兼容 Core Data 版的读取写法

extension Bill {
    /// `bill.amountDouble` 在 Core Data 版中的等价写法
    var amountDouble: Double {
        NSDecimalNumber(decimal: amount ?? .zero).doubleValue
    }

    /// `bill.amountString` 的等价写法（CSV 导出使用）
    var amountString: String {
        NSDecimalNumber(decimal: amount ?? .zero).stringValue
    }
}

