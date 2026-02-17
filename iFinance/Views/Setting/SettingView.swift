//
//  SettingView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/31.
//

import SwiftUI

struct SettingView: View {
    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system
    
    // 动态读取版本号，避免硬编码
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("关于你") {
                    NavigationLink(destination: ProfileView()) {
                        Label("个人设置", systemImage: "person.circle")
                    }
                }
                
                Section("iCloud") {
                    NavigationLink(destination: iCloudSyncView()) {
                        Label("iCloud 云同步设置", systemImage: "icloud")
                    }
                }
                
                Section("账单导入导出") {
                    // ✅ 去掉多余的 List 嵌套
                    NavigationLink("账单导入") {
                        Text("账单导入，功能开发中...")
                    }
                    NavigationLink("账单导出") {
                        Text("账单导出，功能开发中...")
                    }
                }
                
                Section("外观") {
                    Picker("主题模式", selection: $selectedTheme) {
                        Text("浅色").tag(ThemeMode.light)
                        Text("深色").tag(ThemeMode.dark)
                        Text("跟随系统").tag(ThemeMode.system)
                    }
                    .pickerStyle(.menu)
                }
                
                Section("通用") {
                    NavigationLink("语言") { Text("功能开发中") }
                }
                
                Section("关于") {
                    NavigationLink("帮助与反馈") { Text("功能开发中") }
                    NavigationLink("关于我们") { Text("功能开发中") }
                    // ✅ 动态版本号
                    HStack {
                        Text("版本信息")
                        Spacer()
                        Text("v\(appVersion)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .scrollIndicators(.automatic)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HeaderView(isTransactionView: false)
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    SettingView()
}
