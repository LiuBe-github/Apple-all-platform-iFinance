//
//  CategoryPieView.swift
//  iFinance
//
//  分类占比环形图（预算页与趋势页共用）：
//  环形图 + 点选扇区高亮 + 中心显示选中分类与金额 + 分类明细列表（含占比与合计）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI
import Charts

struct CategoryPieView: View {
    let slices: [CategorySlice]
    let accent: Color
    let kind: CategoryKind
    /// 无数据时的本地化文案 key
    let emptyKey: String

    @State private var selectedAngle: Double?
    @State private var selectedRawValue: String?

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 2
        f.locale = .autoupdatingCurrent
        return f
    }()

    private static func amount(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "¥0"
    }

    private var total: Double {
        CategoryBreakdown.total(of: slices)
    }

    var body: some View {
        if slices.isEmpty {
            emptyState
        } else {
            VStack(spacing: AppSpacing.lg) {
                donutChart
                breakdownList
            }
        }
    }

    // MARK: - 环形图

    private var donutChart: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value(L10n.string("bill.amount_legend"), slice.amount),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(kind.color(for: slice.rawValue))
            .cornerRadius(4)
            .opacity(selectedRawValue == nil || selectedRawValue == slice.rawValue ? 1 : 0.4)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .onChange(of: selectedAngle) { _, newAngle in
            HapticManager.shared.selectionChanged()
            selectedRawValue = newAngle.map { rawValue(at: $0) } ?? nil
        }
        .chartBackground { _ in
            if let current = selectedSlice {
                VStack(spacing: AppSpacing.xs) {
                    Text(kind.displayName(for: current.rawValue))
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                    Text(Self.amount(current.amount))
                        .font(AppTypography.amount(15, weight: .bold))
                        .foregroundStyle(.primary)
                        .appNumericTransition(value: current.amount)
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .appAnimation(AppMotion.quick, value: current.rawValue)
            }
        }
        .frame(height: AppLayout.chartHeightRegular + 50)
        .padding(.horizontal, AppSpacing.sm)
        .appAnimation(AppMotion.quick, value: selectedRawValue)
    }

    private var selectedSlice: CategorySlice? {
        guard let raw = selectedRawValue else { return nil }
        return slices.first { $0.rawValue == raw }
    }

    /// 根据点选角度定位分类（按累计金额）
    private func rawValue(at angle: Double) -> String? {
        guard total > 0 else { return nil }
        var cumulative: Double = 0
        for slice in slices {
            cumulative += slice.amount
            if angle <= cumulative { return slice.rawValue }
        }
        return slices.last?.rawValue
    }

    // MARK: - 明细列表（兼作图例）

    private var breakdownList: some View {
        VStack(spacing: 1) {
            ForEach(slices) { slice in
                HStack(spacing: AppSpacing.md) {
                    Circle()
                        .fill(kind.color(for: slice.rawValue))
                        .frame(width: 10, height: 10)

                    Text(kind.displayName(for: slice.rawValue))
                        .font(AppTypography.secondary)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: AppSpacing.sm)

                    Text(Self.amount(slice.amount))
                        .font(AppTypography.amount(13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(AppNumberFormat.percent(total > 0 ? slice.amount / total : 0))
                        .font(AppTypography.tiny)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    selectedRawValue == slice.rawValue ? accent.opacity(0.10) : Color.clear
                )
            }

            Divider().opacity(0.5)

            HStack {
                Text(L10n.string("tendency.category.total"))
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Self.amount(total))
                    .font(AppTypography.amount(13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.pie")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(L10n.string(emptyKey))
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: AppLayout.chartHeightCompact)
    }
}

#Preview {
    CategoryPieView(
        slices: [
            CategorySlice(rawValue: "餐饮", amount: 320, count: 8),
            CategorySlice(rawValue: "购物", amount: 180, count: 3),
            CategorySlice(rawValue: "交通", amount: 60, count: 2)
        ],
        accent: .pink,
        kind: .expenditure,
        emptyKey: "tendency.category.empty"
    )
    .padding()
}
