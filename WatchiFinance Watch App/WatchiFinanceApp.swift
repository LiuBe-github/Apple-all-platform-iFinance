//
//  WatchiFinanceApp.swift
//  WatchiFinance Watch App
//

import SwiftUI

@main
struct WatchiFinance_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WatchDataModel.shared)
        }
    }
}
