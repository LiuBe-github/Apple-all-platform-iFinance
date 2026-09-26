//
//  TendencyModels.swift
//  iFinance
//

import Foundation

// MARK: - 数据模型

/// 每日/每小时金额数据点
struct DailyAmount: Identifiable {
    let date: Date
    let value: Double

    /// 稳定 id：用日期而不是每次新建的 UUID，避免图表重绘时全量 diff
    var id: Date { date }
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

    /// 「总收支」卡片的跨度：月 / 6 个月 / 年
    static let netOptions: [SpanOption] = all.filter { [30, 180, 365].contains($0.days) }
}

// MARK: - 常量

enum TendencyConstants {
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
    
}

// MARK: - 日期扩展

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
