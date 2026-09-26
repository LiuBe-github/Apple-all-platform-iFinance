//
//  AssetEntities.swift
//  iFinanceSwiftData
//
//  资产账户与每日快照的 SwiftData 模型（与 Core Data 版 AssetAccount / AssetSnapshot 字段一一对应）。
//

import Foundation
import SwiftData

/// 资产账户（现金 / 储蓄卡 / 信用卡 / 支付账户 / 投资 / 其他）
@Model
final class AssetAccount {

    var id: UUID?
    var name: String
    /// cash / debitCard / creditCard / payment / investment / other
    var type: String
    /// 余额（信用卡等负债填负数）
    var balance: Decimal
    var note: String?
    var includeInTotal: Bool
    /// 与 Core Data `Integer 16` 生成类型一致
    var sortOrder: Int16
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String
    var updatedBy: String

    init(
        id: UUID = UUID(),
        name: String,
        type: String,
        balance: Decimal = 0,
        note: String? = nil,
        includeInTotal: Bool = true,
        sortOrder: Int16 = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String,
        updatedBy: String
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.note = note
        self.includeInTotal = includeInTotal
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
    }
}

/// 资产每日快照（每个自然日一条，同日覆盖写）
@Model
final class AssetSnapshot {

    var id: UUID?
    /// 当天 00:00
    var date: Date
    var totalAssets: Decimal
    var totalLiabilities: Decimal
    var createdAt: Date
    var createdBy: String

    init(
        id: UUID = UUID(),
        date: Date,
        totalAssets: Decimal,
        totalLiabilities: Decimal,
        createdAt: Date = Date(),
        createdBy: String
    ) {
        self.id = id
        self.date = date
        self.totalAssets = totalAssets
        self.totalLiabilities = totalLiabilities
        self.createdAt = createdAt
        self.createdBy = createdBy
    }
}
