//
//  iCloudSyncView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/8.
//

import SwiftUI

struct iCloudSyncView: View {
    @State var isSyncEnabled: Bool = false
    @State var isNetworkStable: Bool = false
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some View {
        Form {
            Section {
                Toggle("icloud.enable_sync", isOn: $isSyncEnabled)
            }
            
            Section {
                HStack {
                    Text("icloud.network")
                    Spacer()
                    if !networkMonitor.isConnected {
                        Text("icloud.network_lost")
                            .foregroundStyle(.red)
                    } else {
                        Text("icloud.network_ok")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .navigationTitle("settings.icloud")
    }
}

#Preview {
    iCloudSyncView()
}
