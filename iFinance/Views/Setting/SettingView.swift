//
//  SettingView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/31.
//

import SwiftUI

struct SettingView: View {
    @AppStorage("selectedTheme") private var selectedTheme: ThemeMode = .system
    
    var body: some View {
        NavigationStack {
            Form {
                Section("关于你") {
                    NavigationLink(destination: ProfileView()) {
                        Text("个人设置")
                    }
                }
                
                Section("iCloud") {
                    NavigationLink(destination: iCloudSyncView()) {
                        Text("iCloud云同步设置")
                    }
                }
                
                Section("账单导入导出") {
                    List {
                        NavigationLink(destination: ProfileView()) {
                            Text("账单导入")
                        }
                        NavigationLink(destination: ProfileView()) {
                            Text("账单导出")
                        }
                    }
                }
                Section("外观") {
                    Picker("主题模式", selection: $selectedTheme) {
                        Text("浅色").tag(ThemeMode.light)
                        Text("深色").tag(ThemeMode.dark)
                        Text("跟随系统").tag(ThemeMode.system)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("通用") {
                    NavigationLink("语言") { Text("功能开发中") }
                }
                
                Section("关于") {
                    NavigationLink("帮助与反馈") { Text("功能开发中") }
                    NavigationLink("关于我们") { Text("功能开发中") }
                    NavigationLink("版本信息") { Text("v1.0.0") }
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
