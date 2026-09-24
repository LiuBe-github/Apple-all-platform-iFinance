import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var avatarImage: Image? = nil
    @State private var selectedAvatar: PhotosPickerItem? = nil
    /// 等待裁剪的图片（非 nil 时弹出裁剪页）
    @State private var pendingAvatarImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                Form {
                    Section {
                        VStack(spacing: AppSpacing.lg) {
                            PhotosPicker(
                                selection: $selectedAvatar,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                ZStack(alignment: .bottomTrailing) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.22)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 92, height: 92)
                                        Group {
                                            if let avatarImage = avatarImage {
                                                avatarImage
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } else {
                                                Image(systemName: "person.fill")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .foregroundStyle(.secondary)
                                                    .padding(AppSpacing.xxl)
                                            }
                                        }
                                        .frame(width: 84, height: 84)
                                        .clipShape(Circle())
                                    }
                                    // 相机角标
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 28, height: 28)
                                            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .offset(x: -2, y: -2)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle(pressedScale: 0.92))

                            Text(authManager.nickname)
                                .font(.title2)
                                .fontWeight(.semibold)

                            if !authManager.currentEmail.isEmpty {
                                Text(authManager.currentEmail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else if !authManager.currentPhone.isEmpty {
                                Text(authManager.currentPhone)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())

                    Section("profile.account") {
                        NavigationLink("profile.change_nickname") {
                            ChangeNicknameView(initialNickname: authManager.nickname) { _ in
                                // 昵称已通过 authManager.nickname 绑定，无需额外操作
                            }
                        }
                        NavigationLink("profile.change_signature") {
                            EditSignatureView(initial: authManager.signature)
                        }
                        NavigationLink("profile.bind_phone") {
                            BindPhoneView(currentPhone: authManager.currentPhone)
                        }
                        NavigationLink("profile.third_party") {
                            ThirdPartyAccountsView()
                        }
                        NavigationLink("profile.bind_email") {
                            BindEmailView(currentEmail: authManager.currentEmail)
                        }
                        NavigationLink("profile.change_password") {
                            ChangePasswordView()
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            authManager.logout()
                        } label: {
                            Text("profile.logout")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appContentWidth(AppLayout.formMaxWidth)
            .navigationTitle("profile.title")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadAvatar()
            }
            .onChange(of: authManager.avatarData) { _, _ in
                loadAvatar()
            }
            .onChange(of: selectedAvatar) { _, newItem in
                Task {
                    if let newItem = newItem {
                        await prepareForCropping(from: newItem)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { pendingAvatarImage != nil },
                set: { if !$0 { pendingAvatarImage = nil } }
            )) {
                if let image = pendingAvatarImage {
                    AvatarCropView(
                        image: image,
                        onCancel: { pendingAvatarImage = nil },
                        onConfirm: { applyCroppedAvatar($0) }
                    )
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func loadAvatar() {
        if let uiImage = AvatarImageCache.shared.image(for: authManager.avatarData) {
            avatarImage = Image(uiImage: uiImage)
        } else {
            avatarImage = nil
        }
    }

    /// 读取相册图片并进入裁剪流程（不再直接等比缩放保存）
    private func prepareForCropping(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            return
        }

        await MainActor.run {
            pendingAvatarImage = uiImage
        }
    }

    /// 裁剪确认后写回（300×300 JPEG，与既有存储格式一致）
    private func applyCroppedAvatar(_ cropped: UIImage) {
        defer {
            pendingAvatarImage = nil
            selectedAvatar = nil
        }
        guard let imageData = cropped.jpegData(compressionQuality: 0.85) else { return }
        authManager.updateAvatar(imageData)
        avatarImage = Image(uiImage: cropped)
        HapticManager.shared.success()
    }

}

private struct ChangeNicknameView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String
    @State private var errorMessage: String?

    init(initialNickname: String, onSaved: @escaping (String) -> Void) {
        _nickname = State(initialValue: initialNickname)
        self.onSaved = onSaved
    }

    let onSaved: (String) -> Void

    var body: some View {
        Form {
            Section("profile.change_nickname") {
                TextField(L10n.string("profile.nickname_placeholder"), text: $nickname)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("common.save") {
                if let error = authManager.updateNickname(nickname) {
                    errorMessage = L10n.string(error)
                } else {
                    onSaved(authManager.nickname)
                    dismiss()
                }
            }
        }
        .navigationTitle("profile.change_nickname")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BindEmailView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var password = ""
    @State private var errorMessage: String?

    init(currentEmail: String) {
        _email = State(initialValue: currentEmail)
    }

    var body: some View {
        Form {
            Section("profile.bind_email") {
                TextField(L10n.string("auth.email_placeholder"), text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                SecureField(L10n.string("auth.current_password"), text: $password)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("common.save") {
                if let error = authManager.updateEmail(newEmail: email, password: password) {
                    errorMessage = L10n.string(error)
                } else {
                    dismiss()
                }
            }
        }
        .navigationTitle("profile.bind_email")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BindPhoneView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var phone: String
    @State private var password = ""
    @State private var errorMessage: String?

    init(currentPhone: String) {
        _phone = State(initialValue: currentPhone)
    }

    var body: some View {
        Form {
            Section("profile.bind_phone") {
                TextField(L10n.string("auth.phone_placeholder"), text: $phone)
                    .keyboardType(.numberPad)
                SecureField(L10n.string("auth.current_password"), text: $password)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("common.save") {
                if let error = authManager.updatePhone(newPhone: phone, password: password) {
                    errorMessage = L10n.string(error)
                } else {
                    dismiss()
                }
            }
        }
        .navigationTitle("profile.bind_phone")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThirdPartyAccountsView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        List {
            Section("profile.third_party") {
                HStack {
                    Label("auth.provider_wechat", systemImage: "message.fill")
                    Spacer()
                    Text(authManager.currentProvider == .wechat ? L10n.string("profile.connected") : L10n.string("profile.not_connected"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("auth.provider_qq", systemImage: "bubble.left.and.bubble.right.fill")
                    Spacer()
                    Text(authManager.currentProvider == .qq ? L10n.string("profile.connected") : L10n.string("profile.not_connected"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("auth.provider_apple", systemImage: "apple.logo")
                    Spacer()
                    Text(authManager.currentProvider == .apple ? L10n.string("profile.connected") : L10n.string("profile.not_connected"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("profile.third_party")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChangePasswordView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("profile.change_password") {
                SecureField(L10n.string("auth.current_password"), text: $currentPassword)
                SecureField(L10n.string("auth.new_password"), text: $newPassword)
                SecureField(L10n.string("auth.confirm_password"), text: $confirmPassword)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("common.save") {
                if let error = authManager.updatePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword,
                    confirmPassword: confirmPassword
                ) {
                    errorMessage = L10n.string(error)
                } else {
                    dismiss()
                }
            }
        }
        .navigationTitle("profile.change_password")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}
