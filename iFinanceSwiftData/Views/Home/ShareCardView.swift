//
//  ShareCardView.swift
//  iFinance
//
//  分享专用卡片视图（包含当日记账统计）
//

import SwiftUI

/// 分享专用卡片视图（包含当日记账统计）
struct ShareCardView: View {
    let sentence: DailySentence
    let backgroundImage: UIImage?
    let dailyBalance: Decimal   // 当日结余
    let incomeTotal: Decimal    // 当日收入
    let expenseTotal: Decimal   // 当日支出
    let billCount: Int          // 当日笔数
    let dateText: String        // 日期文字

    /// 图片区域宽高比（与首页一致）
    private let imageAspectRatio: CGFloat = 0.75

    private var formattedBalance: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 2
        return f.string(from: NSDecimalNumber(decimal: dailyBalance)) ?? "¥0.00"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 上半部分：名言图片（自适应高度） ──
            GeometryReader { geo in
                let w = geo.size.width
                let h = w / imageAspectRatio

                ZStack(alignment: .bottomLeading) {
                    // 背景
                    Group {
                        if let img = backgroundImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: w, height: h)
                                .clipped()
                        } else {
                            placeholderGradient
                                .frame(width: w, height: h)
                        }
                    }

                    // 底部渐变遮罩
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.3),
                            .init(color: .black.opacity(0.85), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: h)

                    // 名言文字
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\u{201C}")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundStyle(.white.opacity(0.25))

                        Text(sentence.content)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)

                        HStack {
                            Spacer()
                            Text("—— \(sentence.note)")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(.white.opacity(0.65))
                                .italic()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
            }
            .aspectRatio(imageAspectRatio, contentMode: .fit)

            // ── 下半部分：当日记账统计 ──
            VStack(spacing: 14) {
                // 日期标题
                Text(dateText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                // 结余金额
                Text(formattedBalance)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(dailyBalance >= 0 ? Color(red: 0.18, green: 0.78, blue: 0.44) : Color(red: 1.0, green: 0.27, blue: 0.23))

                Text(dailyBalance >= 0 ? String(localized: "home.share_surplus") : String(localized: "home.share_deficit"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(dailyBalance >= 0 ? .green : .red)

                // 三栏统计
                HStack(spacing: 20) {
                    statColumn(title: "home.share_income", value: incomeTotal, color: .green)
                    Divider().frame(height: 32)
                    statColumn(title: "home.share_expense", value: expenseTotal, color: .red)
                    Divider().frame(height: 32)
                    statColumn(title: "home.share_count", value: "\(billCount)", color: .blue)
                }
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color(UIColor.secondarySystemBackground))
        }
    }

    private var placeholderGradient: some View {
        let hue = Double(abs(sentence.content.hashValue) % 360) / 360
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.35, brightness: 0.45),
                Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1),
                      saturation: 0.25, brightness: 0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func statColumn(title: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statColumn(title: LocalizedStringKey, value: Decimal, color: Color) -> some View {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 1
        let v = f.string(from: NSDecimalNumber(decimal: value)) ?? "¥0"
        return statColumn(title: title, value: v, color: color)
    }
}

#Preview {
    ShareCardView(
        sentence: DailySentence(content: "投资的关键在于，在别人贪婪时恐惧，在别人恐惧时贪婪。", note: "沃伦·巴菲特", picture2: ""),
        backgroundImage: nil,
        dailyBalance: 1800,
        incomeTotal: 5000,
        expenseTotal: 3200,
        billCount: 12,
        dateText: "4月23日 星期三"
    )
    .frame(width: 375, height: 600)
}
