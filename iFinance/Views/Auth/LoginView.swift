import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    enum AuthMode: String, CaseIterable {
        case login
        case register
    }

    @State private var authMode: AuthMode = .login
    @State private var loginType: AuthManager.LoginFieldType = .email

    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var showResetSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        modePicker
                        typePicker
                        credentialForm
                        socialLoginSection

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showResetSheet) {
                ResetPasswordView(loginType: loginType)
                    .environmentObject(authManager)
            }
            .onAppear {
                authMode = authManager.hasAccount ? .login : .register
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.blue)

            Text(authMode == .login ? "auth.login" : "auth.register")
                .font(.title2)
                .fontWeight(.bold)

            Text(authMode == .login ? "auth.login_hint" : "auth.register_hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var modePicker: some View {
        Picker("", selection: $authMode) {
            Text("auth.login").tag(AuthMode.login)
            Text("auth.register").tag(AuthMode.register)
        }
        .pickerStyle(.segmented)
        .onChange(of: authMode) { _, _ in
            errorMessage = nil
        }
    }

    private var typePicker: some View {
        Picker("", selection: $loginType) {
            Text("auth.email").tag(AuthManager.LoginFieldType.email)
            Text("auth.phone").tag(AuthManager.LoginFieldType.phone)
        }
        .pickerStyle(.segmented)
        .onChange(of: loginType) { _, _ in
            errorMessage = nil
        }
    }

    private var credentialForm: some View {
        VStack(spacing: 12) {
            if loginType == .email {
                TextField(String(localized: "auth.email_placeholder"), text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(String(localized: "auth.phone_placeholder"), text: $phone)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            SecureField(String(localized: "auth.password"), text: $password)
                .textFieldStyle(.roundedBorder)

            if authMode == .register {
                SecureField(String(localized: "auth.confirm_password"), text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                submit()
            } label: {
                Text(authMode == .login ? "auth.login" : "auth.register_now")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)

            if authMode == .login {
                Button("auth.forgot_password") {
                    showResetSheet = true
                }
                .font(.footnote)
                .foregroundStyle(.blue)
            }
        }
        .padding(16)
        .appGlassCard(cornerRadius: 20)
    }

    private var socialLoginSection: some View {
        VStack(spacing: 10) {
            HStack {
                Rectangle().fill(.secondary.opacity(0.2)).frame(height: 1)
                Text("auth.third_party_login")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle().fill(.secondary.opacity(0.2)).frame(height: 1)
            }

            HStack(spacing: 12) {
                socialButton(title: String(localized: "auth.provider_wechat"), systemImage: "message.fill", color: Color.green) {
                    errorMessage = authManager.loginWithProvider(.wechat, identifier: "wx_\(UUID().uuidString)")
                }

                socialButton(title: String(localized: "auth.provider_qq"), systemImage: "bubble.left.and.bubble.right.fill", color: Color.blue) {
                    errorMessage = authManager.loginWithProvider(.qq, identifier: "qq_\(UUID().uuidString)")
                }
            }

            Button {
                errorMessage = L10n.string("auth.apple_frontend_only")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                    Text("auth.provider_apple")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(.black, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .appGlassCard(cornerRadius: 20)
    }

    private func socialButton(title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func submit() {
        if authMode == .register {
            errorMessage = authManager.register(
                email: email,
                phone: phone,
                password: password,
                confirmPassword: confirmPassword,
                fieldType: loginType
            )
        } else {
            errorMessage = authManager.login(
                email: email,
                phone: phone,
                password: password,
                fieldType: loginType
            )
        }

        if let errorMessage {
            self.errorMessage = L10n.string(errorMessage)
        }
    }
}

private struct ResetPasswordView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var loginType: AuthManager.LoginFieldType
    @State private var email = ""
    @State private var phone = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var message: String?

    init(loginType: AuthManager.LoginFieldType) {
        _loginType = State(initialValue: loginType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("", selection: $loginType) {
                    Text("auth.email").tag(AuthManager.LoginFieldType.email)
                    Text("auth.phone").tag(AuthManager.LoginFieldType.phone)
                }
                .pickerStyle(.segmented)

                Section("auth.reset_password") {
                    if loginType == .email {
                        TextField(String(localized: "auth.email_placeholder"), text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                    } else {
                        TextField(String(localized: "auth.phone_placeholder"), text: $phone)
                            .keyboardType(.numberPad)
                    }
                    SecureField(String(localized: "auth.new_password"), text: $newPassword)
                    SecureField(String(localized: "auth.confirm_password"), text: $confirmPassword)
                }

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("auth.reset_now") {
                    let result = authManager.resetPassword(
                        email: email,
                        phone: phone,
                        fieldType: loginType,
                        newPassword: newPassword,
                        confirmPassword: confirmPassword
                    )
                    if let result {
                        message = L10n.string(result)
                    } else {
                        dismiss()
                    }
                }
            }
            .navigationTitle("auth.forgot_password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("auth.cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
