import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var nickname: String = UserDefaults.standard.string(forKey: "UserProfileNickname") ?? "用户123"
    @State private var avatarImage: Image? = nil
    @State private var selectedAvatar: PhotosPickerItem? = nil

    private let avatarImageDataKey = "UserProfileAvatarData"

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                Form {
                    Section {
                        VStack(spacing: 16) {
                            PhotosPicker(
                                selection: $selectedAvatar,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                if let avatarImage = avatarImage {
                                    avatarImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            Text(nickname)
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
                        .padding(.vertical, 8)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())

                    Section("profile.account") {
                        NavigationLink("profile.change_nickname") {
                            ChangeNicknameView(initialNickname: nickname) { newName in
                                nickname = newName
                            }
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
            .navigationTitle("profile.title")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                nickname = authManager.nickname
                loadPersistedAvatar()
            }
            .onChange(of: authManager.nickname) { _, newValue in
                nickname = newValue
            }
            .onChange(of: selectedAvatar) { _, newItem in
                Task {
                    if let newItem = newItem {
                        await saveAvatar(from: newItem)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func loadPersistedAvatar() {
        if let imageData = UserDefaults.standard.data(forKey: avatarImageDataKey),
           let uiImage = UIImage(data: imageData) {
            avatarImage = Image(uiImage: uiImage)
        } else {
            avatarImage = nil
        }
    }

    private func saveAvatar(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            return
        }

        let resizedImage = resizeImage(uiImage, targetSize: CGSize(width: 300, height: 300))

        if let imageData = resizedImage.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(imageData, forKey: avatarImageDataKey)
            await MainActor.run {
                avatarImage = Image(uiImage: resizedImage)
            }
        }
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resizedImage
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
                TextField(String(localized: "profile.nickname_placeholder"), text: $nickname)
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
                TextField(String(localized: "auth.email_placeholder"), text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                SecureField(String(localized: "auth.current_password"), text: $password)
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
                TextField(String(localized: "auth.phone_placeholder"), text: $phone)
                    .keyboardType(.numberPad)
                SecureField(String(localized: "auth.current_password"), text: $password)
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
                    Text(authManager.currentProvider == .wechat ? String(localized: "profile.connected") : String(localized: "profile.not_connected"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("auth.provider_qq", systemImage: "bubble.left.and.bubble.right.fill")
                    Spacer()
                    Text(authManager.currentProvider == .qq ? String(localized: "profile.connected") : String(localized: "profile.not_connected"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("auth.provider_apple", systemImage: "apple.logo")
                    Spacer()
                    Text(authManager.currentProvider == .apple ? String(localized: "profile.connected") : String(localized: "profile.not_connected"))
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
                SecureField(String(localized: "auth.current_password"), text: $currentPassword)
                SecureField(String(localized: "auth.new_password"), text: $newPassword)
                SecureField(String(localized: "auth.confirm_password"), text: $confirmPassword)
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
