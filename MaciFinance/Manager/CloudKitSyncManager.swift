//
//  CloudKitSyncManager.swift
//  MaciFinance
//
//  iCloud + CloudKit 数据同步管理器（已暂时禁用，需付费开发者账号）
//  类结构保留以保证编译通过，所有 CloudKit 调用已注释
//

import Foundation
import CoreData
// import CloudKit  // 暂时禁用
import Combine

// MARK: - 同步状态枚举

/// CloudKit 同步的详细状态
enum MacCloudKitSyncState: Equatable {
    case unknown
    case syncing
    case idle
    case noAccount
    case networkUnavailable
    case disabled
    case error(String)

    var displayText: String {
        switch self {
        case .unknown:           return L10n.string("icloud.status_unknown")
        case .syncing:           return L10n.string("icloud.status_syncing")
        case .idle:              return L10n.string("icloud.status_idle")
        case .noAccount:         return L10n.string("icloud.status_no_account")
        case .networkUnavailable: return L10n.string("icloud.status_network")
        case .disabled:          return L10n.string("icloud.status_disabled")
        case .error:             return L10n.string("icloud.status_error")
        }
    }

    var iconName: String {
        switch self {
        case .unknown:            return "questionmark.circle"
        case .syncing:            return "arrow.triangle.2.circlepath"
        case .idle:               return "checkmark.icloud"
        case .noAccount:          return "person.crop.circle.badge.xmark"
        case .networkUnavailable: return "wifi.slash"
        case .disabled:           return "icloud.slash"
        case .error:              return "exclamationmark.icloud"
        }
    }

    var isHealthy: Bool {
        switch self { case .idle, .unknown: return true; default: return false }
    }
}

// MARK: - iCloud 账户状态

enum MaciCloudAccountState {
    case available
    case unavailable
    case restricted
    case couldNotDetermine
}

// MARK: - CloudKit Sync Manager（Stub 版本）

@MainActor
final class MacCloudKitSyncManager: ObservableObject {

    static let shared = MacCloudKitSyncManager()

    // MARK: - Published State

    @Published private(set) var syncState: MacCloudKitSyncState = .disabled
    @Published private(set) var accountState: MaciCloudAccountState = .couldNotDetermine
    @Published private(set) var lastSyncDate: Date? = nil
    @Published var isSyncEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: "MaciCloudSyncEnabled")
        }
    }

    // MARK: - Init

    private init() {
        // iCloud 同步已暂时禁用（需付费开发者账号才能使用）
        self.isSyncEnabled = false
        self.syncState = .disabled
    }

    // MARK: - Public API

    /// 手动触发一次同步（暂时禁用）
    func forceSync() {
        // iCloud 同步已禁用
    }

    /// 刷新 iCloud 账户状态（暂时禁用）
    func checkAccountStatus() {
        // iCloud 同步已禁用
        syncState = .disabled
    }
}
