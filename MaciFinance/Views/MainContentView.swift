//
//  MainContentView.swift
//  MaciFinance
//
//  macOS 主内容视图（侧边栏导航）
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
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    Text("iFinance")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Divider()

                // Navigation Items（自定义行样式 + 选中高亮）
                VStack(spacing: 4) {
                    ForEach(NavigationItem.allCases) { item in
                        SidebarItemRow(
                            item: item,
                            isSelected: selectedItem == item
                        ) {
                            HapticManager.shared.selectionChanged()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedItem = item
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 12)

                Spacer()
            }
        } detail: {
            ZStack {
                AppBackgroundView()

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
                .transition(.opacity.combined(with: .scale(scale: 0.99)))
            }
            .animation(.easeInOut(duration: 0.22), value: selectedItem)
        }
    }
}

// MARK: - 侧边栏行

private struct SidebarItemRow: View {
    let item: NavigationItem
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 22)
                    .symbolEffect(.bounce, value: isSelected)

                Text(item.titleKey)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.accentColor.opacity(0.16)
                        : (isHovering ? Color.primary.opacity(0.06) : Color.clear)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
