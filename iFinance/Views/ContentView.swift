//
//  ContentView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/7.
//

import SwiftUI
internal import CoreData

struct ContentView: View {
    enum Tab {
        case transaction
        case tendency
        case setting
    }
    
    @State private var selection: Tab = .transaction
    
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView(selection: $selection) {
            TransactionView()
                .tabItem {
                    Label("账本", systemImage: "yensign") // MARK: 做transaction的好国际化
                }
                .tag(Tab.transaction)
            
            TendencyView()
                .tabItem {
                    Label("消费趋势", systemImage: "chart.bar") // MARK: 做好tendency的国际化
                }
                .tag(Tab.tendency)
            
            SettingView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(Tab.setting)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
