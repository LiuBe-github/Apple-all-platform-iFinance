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
                Toggle("开启同步", isOn: $isSyncEnabled)
            }
            
            Section {
                HStack {
                    Text("网络")
                    Spacer()
                    if !networkMonitor.isConnected {
                        Text("网络丢失")
                            .foregroundStyle(.red)
                    } else {
                        Text("正常")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .navigationTitle("iCloud云同步设置")
    }
}

#Preview {
    iCloudSyncView()
}
