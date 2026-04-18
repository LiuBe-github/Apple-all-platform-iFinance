//
//  MainContentView.swift
//  MaciFinance
//

import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case bills = "Bills"
    case statistics = "Statistics"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .bills: return "list.bullet.clipboard"
        case .statistics: return "chart.bar"
        case .settings: return "gearshape"
        }
    }

    var titleKey: String {
        switch self {
        case .dashboard: return "首页"
        case .bills: return "账单"
        case .statistics: return "统计"
        case .settings: return "设置"
        }
    }
}

struct MainContentView: View {
    @State private var selectedItem: NavigationItem = .dashboard
    @State private var showAddBillSheet = false

    var body: some View {
        NavigationSplitView {
            // MARK: - Sidebar
            VStack(spacing: 0) {
                // App Header
                HStack(spacing: 10) {
                    Image(systemName: "yensign.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.blue)
                    Text("iFinance")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Divider()

                // Navigation Items
                List(NavigationItem.allCases, selection: $selectedItem) { item in
                    Label(item.titleKey, systemImage: item.icon)
                        .font(.system(size: 13, weight: .medium))
                        .tag(item)
                }
                .listStyle(.sidebar)
                .scrollDisabled(true)

                Spacer()

                // Quick Add Button at bottom
                Button(action: { showAddBillSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("记一笔")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(12)
            }
        } detail: {
            Group {
                switch selectedItem {
                case .dashboard:
                    DashboardView()
                        .navigationTitle("首页")
                case .bills:
                    BillListView()
                        .navigationTitle("账单明细")
                case .statistics:
                    StatisticsView()
                        .navigationTitle("统计分析")
                case .settings:
                    SettingsView()
                        .navigationTitle("设置")
                }
            }
            .toolbar {
                if selectedItem == .bills {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showAddBillSheet = true }) {
                            Label("记一笔", systemImage: "plus.circle.fill")
                                .labelStyle(.titleAndIcon)
                        }
                        .help("新增账单")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddBillSheet) {
            AddBillSheet()
                .frame(width: 520, height: 480)
        }
    }
}
