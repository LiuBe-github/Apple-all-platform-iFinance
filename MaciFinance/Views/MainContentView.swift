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
        case .dashboard: return L10n.string("mac.nav.home")
        case .bills: return L10n.string("mac.nav.bills")
        case .statistics: return L10n.string("mac.nav.statistics")
        case .settings: return L10n.string("mac.nav.settings")
        }
    }
}

struct MainContentView: View {
    @State private var selectedItem: NavigationItem = .dashboard

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

                // Navigation Items (仅数据展示，不含增删改)
                List(NavigationItem.allCases, selection: $selectedItem) { item in
                    Label(item.titleKey, systemImage: item.icon)
                        .font(.system(size: 13, weight: .medium))
                        .tag(item)
                }
                .listStyle(.sidebar)
                .scrollDisabled(true)

                Spacer()
            }
        } detail: {
            Group {
                switch selectedItem {
                case .dashboard:
                    DashboardView()
                        .navigationTitle(L10n.string("mac.nav.dashboard_title"))
                case .bills:
                    BillListView()
                        .navigationTitle(L10n.string("mac.nav.bills_title"))
                case .statistics:
                    StatisticsView()
                        .navigationTitle(L10n.string("mac.nav.statistics_title"))
                case .settings:
                    SettingsView()
                        .navigationTitle(L10n.string("mac.nav.settings_title"))
                }
            }
        }
    }
}
