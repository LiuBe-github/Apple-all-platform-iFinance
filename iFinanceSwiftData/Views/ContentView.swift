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

    /// 有头像时用头像，无头像时回落到默认人像（与设置页 / 个人中心的默认头像一致）。
    /// 这里只能用**已经渲染成固定尺寸的圆形缩略图位图**：`.tabItem` 中没有固有尺寸的
    /// `resizable()` 图片会被拉伸铺满整个标签栏。
    @ViewBuilder
    private var tabAvatarIcon: some View {
        if let thumbnail = AvatarImageCache.shared.thumbnail(
            for: authManager.avatarData,
            diameter: AppLayout.tabBarIcon
        ) {
            // 缩略图已是固定尺寸位图：不要再 resizable（会被拉伸铺满标签栏），
            // 也已在 UIImage 层标记 alwaysOriginal（标签栏会模板化非符号图片）
            Image(uiImage: thumbnail)
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
