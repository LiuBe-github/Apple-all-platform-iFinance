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
        case home
        case transaction
        case tendency
        case setting
    }
    
    @State private var selection: Tab = .home
    
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label("tab.home", systemImage: "house")
                }
                .tag(Tab.home)
            
            TransactionView()
                .tabItem {
                    Label("tab.transaction", systemImage: "long.text.page.and.pencil.fill")
                }
                .tag(Tab.transaction)
            
            TendencyView()
                .tabItem {
                    Label("tab.tendency", systemImage: "chart.bar")
                }
                .tag(Tab.tendency)
            
            SettingView()
                .tabItem {
                    Label("tab.setting", systemImage: "gear")
                }
                .tag(Tab.setting)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
