//
//  Transaction.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/8.
//

import SwiftUI
internal import CoreData

struct TransactionView: View {
    @State private var isHeaderVisible = true
    @State private var showingAddBillView = false
    @State private var showProfile = false
    @AppStorage("UserProfileAvatarData") private var avatarData: Data?

    // 添加一个 fetch request 来检查是否有账单
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bill.date, ascending: false)],
        animation: .default
    ) private var bills: FetchedResults<Bill>

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(.vertical) {
                    // 预算卡片
                    BudgetCardView()
                        .padding(.horizontal)
                        .padding(.bottom)

                    // 根据账单数量决定显示什么
                    if !bills.isEmpty {
                        // 有账单时显示 BillsCardView
                        BillsCardView()
                            .padding(.horizontal)
                            .padding(.bottom)
                    } else {
                        // 没有账单时显示提示文字
                        VStack {
                            Spacer()
                            Text("transaction.empty")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxHeight: 400)
                        .padding(.horizontal)
                        .appGlassCard(cornerRadius: 20)
                    }
                }
            }
            .navigationTitle("transaction.title")
            .scrollIndicators(.automatic)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAddBillView = true
                    } label: {
                        Text("header.add_bill")
                            .font(.title.bold())
                            .foregroundStyle(.blue)
                            .buttonStyle(.plain)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Group {
                            if let data = avatarData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 35, height: 35)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 26))
                            }
                        }
                        .foregroundColor(.blue)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("header.edit_profile")
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showingAddBillView) {
                AddBillView()
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    TransactionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
