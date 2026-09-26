//
//  AssetBreakdown.swift
//  iFinance
//
//  资产的**纯逻辑**（总额 / 负债 / 类型占比 / 快照差值），不依赖具体数据栈，
//  Core Data 版与 SwiftData 版共用同一份实现与同一批单测。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation

// MARK: - 账户类型

enum AssetType: String, CaseIterable {
    case cash
    case debitCard
    case creditCard
    case payment
    case investment
    case other

    var localizedKey: String { "asset.type.\(rawValue)" }

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .debitCard: return "creditcard"
        case .creditCard: return "creditcard.fill"
        case .payment: return "wallet.pass"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .other: return "ellipsis.circle"
        }
    }

    /// 环形图与列表的固定顺序（与 CaseIterable 顺序一致）
    static var displayOrder: [AssetType] { allCases }
}

// MARK: - 账户快照

/// 资产账户的只读快照（视图与纯函数共用）
struct AssetAccountSnapshot: Equatable, Identifiable {
    let id: UUID
    let name: String
    let type: AssetType
    /// 余额；信用卡等负债为负数
    let balance: Double
    let note: String?
    let includeInTotal: Bool
    /// 与 Core Data `Integer 16` 生成类型一致
    let sortOrder: Int16
}

/// 每日快照的只读快照
struct AssetSnapshotValue: Equatable {
    let date: Date
    let totalAssets: Double
    let totalLiabilities: Double

    var net: Double { totalAssets - totalLiabilities }
}

// MARK: - 聚合

enum AssetBreakdown {

    /// 计入总资产的账户（`includeInTotal` 为真）
    static func included(_ accounts: [AssetAccountSnapshot]) -> [AssetAccountSnapshot] {
        accounts.filter(\.includeInTotal)
    }

    static func totalAssets(_ accounts: [AssetAccountSnapshot]) -> Double {
        included(accounts).filter { $0.balance > 0 }.reduce(0) { $0 + $1.balance }
    }

    static func totalLiabilities(_ accounts: [AssetAccountSnapshot]) -> Double {
        abs(included(accounts).filter { $0.balance < 0 }.reduce(0) { $0 + $1.balance })
    }

    static func netTotal(_ accounts: [AssetAccountSnapshot]) -> Double {
        totalAssets(accounts) - totalLiabilities(accounts)
    }

    /// 环形图数据：仅计入总资产且余额 > 0 的账户，按类型聚合，顺序固定为 `AssetType.displayOrder`；
    /// 返回的占比以「总资产」为分母（合计可能因四舍五入略有偏差）。
    static func breakdown(_ accounts: [AssetAccountSnapshot]) -> [(type: AssetType, amount: Double, share: Double)] {
        let positive = included(accounts).filter { $0.balance > 0 }
        let total = positive.reduce(0) { $0 + $1.balance }
        guard total > 0 else { return [] }

        var sums: [AssetType: Double] = [:]
        for account in positive {
            sums[account.type, default: 0] += account.balance
        }
        return AssetType.displayOrder.compactMap { type in
            guard let amount = sums[type], amount > 0 else { return nil }
            return (type: type, amount: amount, share: amount / total)
        }
    }

    /// 较上次快照的变化：返回净额差值与比率（上一次净额为 0 时只给差值，比率为 nil）
    static func change(
        current: AssetSnapshotValue,
        previous: AssetSnapshotValue?
    ) -> (amount: Double, ratio: Double?)? {
        guard let previous else { return nil }
        let amount = current.net - previous.net
        let ratio: Double? = previous.net == 0 ? nil : amount / abs(previous.net)
        return (amount, ratio)
    }

    /// 同日 upsert 的判定：找出需要覆盖写入的历史快照下标（同一天 00:00）
    static func upsertIndex(
        for date: Date,
        in snapshots: [AssetSnapshotValue],
        calendar: Calendar = .current
    ) -> Int? {
        let day = calendar.startOfDay(for: date)
        return snapshots.firstIndex { calendar.startOfDay(for: $0.date) == day }
    }
}
