//
//  ContentView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/7.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    enum Tab {
        case home
        case transaction
        case todo
        case tendency
        case setting
    }
    
    @State private var selection: Tab = .home
    
    @Environment(\.modelContext) private var viewContext
    @EnvironmentObject private var authManager: AuthManager
    
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
            
            TodoTabView()
                .tabItem {
                    Label("tab.todo", systemImage: "checklist")
                }
                .tag(Tab.todo)
            
            TendencyView()
                .tabItem {
                    Label("tab.tendency", systemImage: "chart.bar")
                }
                .tag(Tab.tendency)
            
            SettingView()
                .tabItem {
                    Label {
                        Text("tab.setting")
                    } icon: {
                        tabAvatarIcon
                    }
                }
                .tag(Tab.setting)
        }
        .onChange(of: selection) { _, _ in
            HapticManager.shared.selectionChanged()
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    // MARK: - 「我的」标签图标

    /// 有头像时用头像，无头像时回落到默认人像（与设置页 / 个人中心的默认头像一致）
    @ViewBuilder
    private var tabAvatarIcon: some View {
        if let uiImage = AvatarImageCache.shared.image(for: authManager.avatarData) {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: AppLayout.tabBarIcon, height: AppLayout.tabBarIcon)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environment(\.modelContext, PersistenceController.preview.container.viewContext)
}
