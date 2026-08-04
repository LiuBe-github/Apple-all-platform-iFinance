//
//  iCloudSyncView.swift
//  MaciFinance
//
//  Mac 端 iCloud 同步设置视图
//

import SwiftUI

struct MaciCloudSyncView: View {
    @StateObject private var syncManager = MacCloudKitSyncManager.shared

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale.current
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 同步开关
            Toggle(L10n.string("icloud.enable_sync"), isOn: $syncManager.isSyncEnabled)
                .toggleStyle(.switch)
                .onChange(of: syncManager.isSyncEnabled) { _, newValue in
                    if newValue {
                        syncManager.checkAccountStatus()
                    }
                }
                .padding(.bottom, 4)

            Text(L10n.string("icloud.sync_description"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // 同步状态
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: syncManager.syncState.iconName)
                        .foregroundStyle(syncManager.syncState.isHealthy ? .green : .orange)
                    Text(L10n.string("icloud.status_section"))
                        .fontWeight(.medium)
                    Spacer()
                    if case .syncing = syncManager.syncState {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                HStack {
                    Text(L10n.string("icloud.account_status"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(accountStatusText)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(L10n.string("icloud.last_sync"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let date = syncManager.lastSyncDate {
                        Text(dateFormatter.string(from: date))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L10n.string("icloud.never_synced"))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    syncManager.forceSync()
                } label: {
                    Label(L10n.string("icloud.sync_now"), systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(syncManager.syncState == .syncing || !syncManager.isSyncEnabled)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(20)
        .frame(width: 400)
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
    MaciCloudSyncView()
}
