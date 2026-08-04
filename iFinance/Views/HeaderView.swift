//
//  HeaderView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/9.
//

import SwiftUI

struct HeaderView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showingAddBillView = false

    var isTransactionView: Bool = false

    var body: some View {
        HStack {
            if isTransactionView {
                Button {
                    showingAddBillView = true
                } label: {
                    Text("header.add_bill")
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
                    if let data = authManager.avatarData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 45, height: 45)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 26))
                    }
                }
                .foregroundColor(.blue)
                .accessibilityLabel("header.edit_profile")
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
            .environmentObject(AuthManager.shared)
    }
}
