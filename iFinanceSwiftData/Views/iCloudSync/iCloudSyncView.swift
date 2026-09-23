//
//  iCloudSyncView.swift
//  iFinance
//
//  iCloud 同步设置页面
//

import SwiftUI

struct iCloudSyncView: View {
    @StateObject private var syncManager = CloudKitSyncManager.shared

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale.current
        return f
    }

    var body: some View {
        List {
            // 同步开关
            Section {
                Toggle(L10n.string("icloud.enable_sync"), isOn: $syncManager.isSyncEnabled)
                    .onChange(of: syncManager.isSyncEnabled) { _, newValue in
                        if newValue {
                            syncManager.checkAccountStatus()
                        }
                    }
            } footer: {
                Text(L10n.string("icloud.sync_description"))
            }

            // 同步状态
            Section(L10n.string("icloud.status_section")) {
                // 状态行
                HStack {
                    Image(systemName: syncManager.syncState.iconName)
                        .foregroundStyle(syncManager.syncState.isHealthy ? Color.green : Color.orange)
                    Text(syncManager.syncState.displayText)
                        .foregroundStyle(syncManager.syncState.isHealthy ? .primary : Color.orange)

                    Spacer()

                    if case .syncing = syncManager.syncState {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                // 账户状态
                HStack {
                    Text(L10n.string("icloud.account_status"))
                    Spacer()
                    Text(accountStatusText)
                        .foregroundStyle(.secondary)
                }

                // 上次同步时间
                HStack {
                    Text(L10n.string("icloud.last_sync"))
                    Spacer()
                    if let date = syncManager.lastSyncDate {
                        Text(dateFormatter.string(from: date))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L10n.string("icloud.never_synced"))
                            .foregroundStyle(.secondary)
                    }
                }

                // 手动同步按钮
                Button {
                    syncManager.forceSync()
                } label: {
                    HStack {
                        Text(L10n.string("icloud.sync_now"))
                        Spacer()
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(syncManager.syncState == .syncing || !syncManager.isSyncEnabled)
            }
        }
        .navigationTitle(L10n.string("settings.icloud"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncManager.checkAccountStatus()
        }
    }

    private var accountStatusText: String {
        switch syncManager.accountState {
        case .available:    return L10n.string("icloud.account_available")
        case .unavailable:  return L10n.string("icloud.account_unavailable")
        case .restricted:   return L10n.string("icloud.account_restricted")
        case .couldNotDetermine: return L10n.string("icloud.account_unknown")
        }
    }
}

#Preview {
    NavigationStack {
        iCloudSyncView()
    }
}
