//
//  SentenceCardView.swift
//  iFinance
//
//  每日一言卡（毛玻璃卡片）：标题 + 「换一句」按钮 + 引言 + 作者署名
//

import SwiftUI

/// 每日一言卡
struct SentenceCardView: View {
    let sentence: DailySentence

    /// 点击「换一句」时的回调；为 nil 时不显示按钮
    var onChangeQuote: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // ── 标题行 + 换一句 ──
            HStack(spacing: AppSpacing.sm) {
                Text(L10n.string("home.quote.title"))
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: AppSpacing.sm)

                if let onChangeQuote {
                    Button(action: onChangeQuote) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.6))
                    }
                    .foregroundStyle(.secondary)
                    .buttonStyle(.scalePress)
                    .accessibilityLabel(L10n.string("home.change_quote"))
                }
            }

            // ── 引言 ──
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Text("\u{201C}")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(.tertiary)
                    .offset(y: -6)
                    .accessibilityHidden(true)

                Text(sentence.content)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(5)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // ── 作者 ──
            HStack {
                Spacer()
                Text("—— \(sentence.note)")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AppLayout.cardPaddingCozy)
        .padding(.vertical, AppLayout.cardPadding)
        .appGlassCard(cornerRadius: AppRadius.sheet)
    }
}

#Preview {
    SentenceCardView(
        sentence: DailySentence(
            content: "风险来自于你不知道自己在做什么。",
            note: "沃伦·巴菲特"
        ),
        onChangeQuote: {}
    )
    .padding()
}
