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
                    Label("首页", systemImage: "house")
                }
                .tag(Tab.home)
            
            TransactionView()
                .tabItem {
                    Label("账本", systemImage: "long.text.page.and.pencil.fill") // MARK: 做transaction的好国际化
                }
                .tag(Tab.transaction)
            
            TendencyView()
                .tabItem {
                    Label("趋势", systemImage: "chart.bar") // MARK: 做好tendency的国际化
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
