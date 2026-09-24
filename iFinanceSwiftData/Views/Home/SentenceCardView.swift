//
//  SentenceCardView.swift
//  iFinance
//
//  每日一言（纯文字）：图片能力已移除，作为「概况」页下方的补充信息。
//

import SwiftUI

/// 每日一言（纯文字行：引言 + 作者）
struct SentenceCardView: View {
    let sentence: DailySentence

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(sentence.content)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("—— \(sentence.note)")
                .font(AppTypography.tiny)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.xs)
    }
}

#Preview {
    SentenceCardView(sentence: DailySentence(
        content: "风险来自于你不知道自己在做什么。",
        note: "沃伦·巴菲特"
    ))
    .padding()
}

