//
//  HeaderView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/9.
//

import SwiftUI

struct HeaderView: View {
    @State private var showingAddBillView = false
    
    // 从 UserDefaults 读取头像数据（自动监听变化）
    @AppStorage("UserProfileAvatarData") private var avatarData: Data?
    
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
                Group {
                    if let avatarData = avatarData,
                       let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 45, height: 45)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 30))
                    }
                }
                .foregroundColor(.blue)
                .accessibilityLabel("编辑个人资料")
                .accessibilityAddTraits(.isButton)
            }
            .padding()
        }
        .sheet(isPresented: $showingAddBillView) {
            AddBillView()
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
