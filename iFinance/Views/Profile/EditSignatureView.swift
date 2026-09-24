//
//  EditSignatureView.swift
//  iFinance
//
//  编辑个性签名（设置页用户名下方的描述文案）
//

import SwiftUI

struct EditSignatureView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var errorMessage: String?

    init(initial: String = "") {
        _text = State(initialValue: initial)
    }

    private var trimmedCount: Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var isTooLong: Bool {
        trimmedCount > AuthManager.signatureMaxLength
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.string("profile.signature_placeholder"), text: $text, axis: .vertical)
                        .lineLimit(1...3)
                } footer: {
                    HStack(spacing: AppSpacing.sm) {
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                        Text("\(trimmedCount)/\(AuthManager.signatureMaxLength)")
                            .monospacedDigit()
                            .foregroundStyle(isTooLong ? .red : .secondary)
                    }
                }

                Section {
                    Button(L10n.string("common.save")) { save() }
                }
            }
            .navigationTitle(L10n.string("profile.change_signature"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) { dismiss() }
                }
            }
        }
    }

    private func save() {
        if let error = authManager.updateSignature(text) {
            errorMessage = L10n.string(error)
            HapticManager.shared.error()
        } else {
            HapticManager.shared.success()
            dismiss()
        }
    }
}

#Preview {
    EditSignatureView(initial: "把每一笔都记清楚")
        .environmentObject(AuthManager.shared)
}
