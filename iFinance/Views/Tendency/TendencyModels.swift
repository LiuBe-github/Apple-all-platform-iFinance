//
//  TendencyModels.swift
//  iFinance
//

import Foundation

// MARK: - 数据模型

/// 每日/每小时金额数据点
struct DailyAmount: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - 时间跨度选项

struct SpanOption: Identifiable, Hashable {
    let id = UUID()
    let titleKey: String
    let days: Int

    static let all: [SpanOption] = [
        .init(titleKey: "tendency.span_day", days: 1),
        .init(titleKey: "tendency.span_week", days: 7),
        .init(titleKey: "tendency.span_month", days: 30),
        .init(titleKey: "tendency.span_6month", days: 180),
        .init(titleKey: "tendency.span_year", days: 365)
    ]
}

// MARK: - 图表类型

enum ChartDisplayType: String, CaseIterable {
    case line = "折线图"
    case bar = "柱状图"

    var displayName: String {
        switch self {
        case .line: return String(localized: "chart.type_line", defaultValue: "折线图")
        case .bar: return String(localized: "chart.type_bar", defaultValue: "柱状图")
        }
    }
}

// MARK: - 常量

enum TendencyConstants {
    /// 热力图单元格大小
    static let heatmapCellSize: CGFloat = 12
    
    /// 图表高度
    static let chartHeight: CGFloat = 220
    
    /// 卡片内边距
    static let cardPadding: CGFloat = 16
    
    /// 卡片圆角
    static let cardCornerRadius: CGFloat = 24
    
    /// 统计药丸圆角
    static let statPillCornerRadius: CGFloat = 14
    
    /// 默认追踪天数（用于图表数据）
    static let defaultTrailingDays = 365
    
    /// 热力图追踪天数
    static let heatmapTrailingDays = 364
    
    /// 选择器宽度
    static let chartTypePickerWidth: CGFloat = 140
    
    /// 图表水平内边距
    static let chartHorizontalPadding: CGFloat = 6
    
    /// 触摸检测半径
    static let touchDetectionRadius: CGFloat = 26
}

// MARK: - 日期扩展

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
