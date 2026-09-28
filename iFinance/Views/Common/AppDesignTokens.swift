//
//  AppDesignTokens.swift
//  iFinance
//
//  统一布局 token（按 HIG 重定尺度）：间距 / 圆角 / 内容宽度 / 字体。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import SwiftUI

// MARK: - 间距（4pt 网格）

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    /// 页面级区块之间
    static let section: CGFloat = 32
    /// 页面左右安全边距
    static let screen: CGFloat = 20
}

// MARK: - 圆角

enum AppRadius {
    /// 小控件（键帽、标签底、输入框）
    static let control: CGFloat = 10
    /// 行内小块（列表行、分类块）
    static let row: CGFloat = 14
    /// 标准卡片
    static let card: CGFloat = 16
    /// 大卡片 / 弹层 / 图片容器
    static let sheet: CGFloat = 22
}

// MARK: - 布局

enum AppLayout {
    /// 卡片内边距（紧凑）
    static let cardPadding: CGFloat = 16
    /// 卡片内边距（宽松，用于首页主卡片）
    static let cardPaddingCozy: CGFloat = 20
    /// iPad / 大屏内容最大宽度（超出后居中显示）
    static let contentMaxWidth: CGFloat = 700
    /// 表单类内容最大宽度
    static let formMaxWidth: CGFloat = 640
    /// 最小可点行高（HIG）
    static let listRowMinHeight: CGFloat = 44
    /// 头像等图标容器
    static let avatarLarge: CGFloat = 84
    static let avatarMedium: CGFloat = 56
    static let iconTile: CGFloat = 32
    /// 图表高度（紧凑 / 常规）
    static let chartHeightCompact: CGFloat = 150
    static let chartHeightRegular: CGFloat = 190
    /// 备忘编辑器的最小高度
    static let editorMinHeight: CGFloat = 220
    /// 热力图单元格
    static let heatmapCell: CGFloat = 12
    /// 标签栏图标（「我的」标签用头像时的圆形直径）
    static let tabBarIcon: CGFloat = 25
    /// 进入后台时整页隐私模糊的半径（仅在开启应用锁时生效）
    static let privacyBlurRadius: CGFloat = 20
}

// MARK: - 字体（语义字体，跟随 Dynamic Type）

enum AppTypography {
    /// 页面主标题（首页日期、设置页标题）
    static let screenTitle = Font.title2.weight(.semibold)
    /// 区块标题
    static let sectionTitle = Font.headline
    /// 正文
    static let body = Font.body
    /// 次级说明
    static let secondary = Font.subheadline
    /// 辅助说明
    static let caption = Font.footnote
    /// 极小标注
    static let tiny = Font.caption2
    /// 大号金额数字（保留字号但等宽，配合 appAmountStyle 自适应缩放）
    static func amount(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - 便捷修饰器

enum AppNumberFormat {
    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.locale = .autoupdatingCurrent
        return f
    }()

    /// 百分比：最多两位小数、去掉尾随零（0.43 → 43%、0.432 → 43.2%、0.4325 → 43.25%）
    static func percent(_ ratio: Double) -> String {
        percentFormatter.string(from: NSNumber(value: ratio))
            ?? "\(Int((ratio * 100).rounded()))%"
    }
}

extension View {
    /// 大号金额数字：等宽数字 + 禁止换行 + 自动缩放，避免 Dynamic Type 撑破卡片
    func appAmountStyle(size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        self
            .font(AppTypography.amount(size, weight: weight))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    /// 内容最大宽度（iPad 居中，避免卡片被拉满整屏）
    func appContentWidth(_ maxWidth: CGFloat = AppLayout.contentMaxWidth) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }

    /// 统一卡片内边距
    func appCardPadding(cozy: Bool = false) -> some View {
        self.padding(cozy ? AppLayout.cardPaddingCozy : AppLayout.cardPadding)
    }
}
