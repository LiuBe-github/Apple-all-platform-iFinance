//
//  HeaderView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/9.
//

import SwiftUI
internal import CoreData

struct HeaderView: View {
    @State private var showingAddBillView = false
    
    var isTransactionView: Bool = false
    
    var body: some View {
        HStack {
            if isTransactionView {
                Button {
                    showingAddBillView = true
                } label: {
                    Text("记一笔！")
                        .font(.title.bold())
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .padding()
                }
            }
            
            Spacer()
            
            NavigationLink {
                ProfileView()
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                    .accessibilityLabel("编辑个人资料")
                    .accessibilityAddTraits(.isButton)
            }
            .padding()
        }
        .sheet(isPresented: $showingAddBillView) {
            AddBillView() // 弹出的视图
                .presentationDragIndicator(.visible)
        }
        .frame(width: 400, height: 10)
    }
}

#Preview {
    NavigationView {
        HeaderView(isTransactionView: true)
    }
}
