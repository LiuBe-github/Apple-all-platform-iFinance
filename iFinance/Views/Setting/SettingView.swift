//
//  SettingView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/31.
//

import SwiftUI

struct SettingView: View {
    var body: some View {
        NavigationSplitView {
            ScrollView(.vertical) {
                
            }
            .navigationTitle("设置")
            .scrollIndicators(.automatic)
//            .toolbar {
//                ToolbarItem(placement: .principal) {
//                    HeaderView(isTransactionView: false)
//                }
//            }
            .navigationBarBackButtonHidden(true)
        } detail: {
            Text("请选择设置项")
        }
    }
}

#Preview {
    SettingView()
}
