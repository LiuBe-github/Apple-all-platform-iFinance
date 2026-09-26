//
//  ScrubSupport.swift
//  iFinance
//
//  Scrub（按住扫读）共享支撑：纯逻辑（可单测）+ 浮层组件，供趋势页两类柱状图复用。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//
//  为什么没有自研拖动手势：
//  契约要求「按下即出指示线 / 拖动吸附 / 松手淡出」以及「不打断页面纵向滚动与返回手势」。
//  Swift Charts 自 iOS 17 起提供 `chartXSelection` 原生选择手势（按下即选、吸附最近数据点、
//  松手清空），并且是官方为可滚动容器设计的交互；如果再叠加一个自研 `DragGesture` 来取连续
//  位移增量，会与页面 ScrollView / 导航返回手势争抢触摸（违反契约 5）。因此这里只保留三项
//  纯逻辑 + 浮层绘制，贴边自动滚动用「选中项贴住窗口边缘 + Task 定时步进窗口」近似实现。
//

import SwiftUI

// MARK: - 纯逻辑（可单测）

enum ScrubSelection {

    /// 选中日期 → 数据点下标（原生选择已吸附到数据点，这里做精确匹配）
    static func index(of date: Date, in dates: [Date]) -> Int? {
        dates.firstIndex(of: date)
    }

    /// 触觉门控：**进入新的数据点才返回 true**；同一点内重复回调、清空选中都不触发。
    /// 契约「扫过 6 个数据点 = 6 次 tick」即：连续 6 次进入新点 → 6 次 true。
    static func shouldTick(from oldIndex: Int?, to newIndex: Int?) -> Bool {
        guard let newIndex else { return false }
        return newIndex != oldIndex
    }

    /// 贴边判定：-1 = 选中窗口最左数据点（继续按住 → 往前翻），1 = 最右，
    /// 0 = 中间 / 未选中 / 窗口只有一个数据点（没有可滚动空间）
    static func edgeHold(index: Int?, count: Int) -> Int {
        guard let index, count > 1, index >= 0, index < count else { return 0 }
        if index == 0 { return -1 }
        if index == count - 1 { return 1 }
        return 0
    }
}

// MARK: - 浮层

/// Scrub 浮层：跟随指示线水平移动，靠近绘图区左右边缘时自动夹在范围内，
/// 底部小三角始终指向指示线（等价于 Apple Health 的边缘对齐切换）。
/// 只做透明度变化，不做位移/缩放 —— Reduce Motion 下天然满足「无位移/缩放」。
struct ScrubCallout<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    /// 绘图区在 overlay 坐标系中的矩形
    let plotRect: CGRect
    /// 指示线在绘图区内的横坐标（0...plotRect.width）
    let anchorX: CGFloat
    /// 是否可见；松手后置 false，由外层用 AppMotion.quick 淡出
    let isVisible: Bool
    @ViewBuilder var content: Content

    @State private var size: CGSize = .zero

    private var bubbleWidth: CGFloat { max(size.width, 1) }
    private var bubbleHeight: CGFloat { max(size.height, 1) }

    var body: some View {
        let minCenter = bubbleWidth / 2
        let maxCenter = max(min(plotRect.width - bubbleWidth / 2, plotRect.width - minCenter), minCenter)
        let centerInPlot = min(max(anchorX, minCenter), maxCenter)
        let pointerOffset = min(max(anchorX - centerInPlot, -bubbleWidth / 2 + 10), bubbleWidth / 2 - 10)
        let fitsAbove = plotRect.minY >= bubbleHeight + 14
        let centerY = fitsAbove
            ? plotRect.minY - bubbleHeight / 2 - 8
            : plotRect.minY + bubbleHeight / 2 + 8

        content
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .frame(maxWidth: max(plotRect.width - AppSpacing.lg, 96), alignment: .leading)
            .background(bubbleBackground)
            .overlay(alignment: fitsAbove ? .bottom : .top) {
                ScrubCalloutPointer(pointsUp: !fitsAbove)
                    .fill(bubbleFill)
                    .frame(width: 12, height: 6)
                    .offset(x: pointerOffset, y: fitsAbove ? 5 : -5)
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .position(x: plotRect.minX + centerInPlot, y: centerY)
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(false)
    }

    private var bubbleFill: Color {
        colorScheme == .dark ? Color(white: 0.14) : Color.white
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
            .fill(bubbleFill)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                    // R13：提高对比度环境下加深描边，选中态更明显
                    .strokeBorder(
                        Color.primary.opacity(colorSchemeContrast == .increased ? 0.55 : 0.10),
                        lineWidth: colorSchemeContrast == .increased ? 1.6 : 0.8
                    )
            )
            .shadow(color: .black.opacity(colorSchemeContrast == .increased ? 0.32 : 0.18), radius: 6, x: 0, y: 3)
    }
}

/// 浮层指向指示线的小三角
struct ScrubCalloutPointer: Shape {
    let pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointsUp {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}
