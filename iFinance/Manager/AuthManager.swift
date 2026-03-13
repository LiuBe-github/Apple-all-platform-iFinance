import Foundation
import Combine
import CryptoKit

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    enum LoginFieldType {
        case email
        case phone
    }

    enum SocialProvider: String {
        case wechat
        case qq
        case apple
    }

    @Published private(set) var isAuthenticated = false
    @Published private(set) var hasAccount = false
    @Published private(set) var currentEmail = ""
    @Published private(set) var currentPhone = ""
    @Published private(set) var nickname = UserDefaults.standard.string(forKey: Keys.nickname) ?? "用户123"
    @Published private(set) var currentProvider: SocialProvider?

    private let defaults = UserDefaults.standard
    private let sessionLifetime: TimeInterval = 7 * 24 * 60 * 60

    private enum Keys {
        static let email = "AuthEmail"
        static let phone = "AuthPhone"
        static let passwordHash = "AuthPasswordHash"
        static let passwordSalt = "AuthPasswordSalt"
        static let isLoggedIn = "AuthIsLoggedIn"
        static let lastActiveAt = "AuthLastActiveAt"
        static let nickname = "UserProfileNickname"
        static let provider = "AuthProvider"
        static let providerID = "AuthProviderID"
    }

    private init() {
        bootstrap()
    }

    func bootstrap() {
        nickname = defaults.string(forKey: Keys.nickname) ?? "用户123"
        currentEmail = defaults.string(forKey: Keys.email) ?? ""
        currentPhone = defaults.string(forKey: Keys.phone) ?? ""
        if let providerRaw = defaults.string(forKey: Keys.provider) {
            currentProvider = SocialProvider(rawValue: providerRaw)
        } else {
            currentProvider = nil
        }

        let hasPasswordAccount = defaults.string(forKey: Keys.passwordHash) != nil &&
            defaults.string(forKey: Keys.passwordSalt) != nil &&
            (!currentEmail.isEmpty || !currentPhone.isEmpty)
        let hasProviderAccount = defaults.string(forKey: Keys.providerID) != nil && currentProvider != nil

        hasAccount = hasPasswordAccount || hasProviderAccount

        let loggedIn = defaults.bool(forKey: Keys.isLoggedIn)
        guard loggedIn else {
            isAuthenticated = false
            return
        }

        let now = Date()
        let lastActive = defaults.object(forKey: Keys.lastActiveAt) as? Date ?? .distantPast
        if now.timeIntervalSince(lastActive) > sessionLifetime {
            logout()
            return
        }

        isAuthenticated = true
        touch()
    }

    func handleAppDidBecomeActive() {
        bootstrap()
        if isAuthenticated {
            touch()
        }
    }

    func handleAppWillResignActive() {
        if isAuthenticated {
            touch()
        }
    }

    @discardableResult
    func register(
        email: String,
        phone: String,
        password: String,
        confirmPassword: String,
        fieldType: LoginFieldType
    ) -> String? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPhone = normalizePhone(phone)

        if fieldType == .email {
            if !isValidEmail(normalizedEmail) {
                return "auth.invalid_email"
            }
        } else {
            if !isValidPhone(normalizedPhone) {
                return "auth.invalid_phone"
            }
        }

        if password.count < 6 {
            return "auth.password_too_short"
        }
        if password != confirmPassword {
            return "auth.password_not_match"
        }

        let salt = UUID().uuidString
        let hash = Self.hash(password: password, salt: salt)

        defaults.set(normalizedEmail, forKey: Keys.email)
        defaults.set(normalizedPhone, forKey: Keys.phone)
        defaults.set(hash, forKey: Keys.passwordHash)
        defaults.set(salt, forKey: Keys.passwordSalt)
        defaults.set(nil, forKey: Keys.provider)
        defaults.set(nil, forKey: Keys.providerID)
        defaults.set(true, forKey: Keys.isLoggedIn)
        defaults.set(Date(), forKey: Keys.lastActiveAt)

        if defaults.string(forKey: Keys.nickname)?.isEmpty != false {
            defaults.set("用户\(Int.random(in: 100...999))", forKey: Keys.nickname)
        }

        currentEmail = normalizedEmail
        currentPhone = normalizedPhone
        currentProvider = nil
        nickname = defaults.string(forKey: Keys.nickname) ?? "用户123"
        hasAccount = true
        isAuthenticated = true
        return nil
    }

    @discardableResult
    func login(email: String, phone: String, password: String, fieldType: LoginFieldType) -> String? {
        guard let storedHash = defaults.string(forKey: Keys.passwordHash),
              let salt = defaults.string(forKey: Keys.passwordSalt) else {
            return "auth.no_account"
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPhone = normalizePhone(phone)
        let storedEmail = defaults.string(forKey: Keys.email)?.lowercased() ?? ""
        let storedPhone = defaults.string(forKey: Keys.phone) ?? ""

        if fieldType == .email {
            guard normalizedEmail == storedEmail else {
                return "auth.invalid_credentials"
            }
        } else {
            guard normalizedPhone == storedPhone else {
                return "auth.invalid_credentials"
            }
        }

        let inputHash = Self.hash(password: password, salt: salt)
        guard inputHash == storedHash else {
            return "auth.invalid_credentials"
        }

        defaults.set(true, forKey: Keys.isLoggedIn)
        defaults.set(Date(), forKey: Keys.lastActiveAt)
        currentProvider = nil
        hasAccount = true
        isAuthenticated = true
        currentEmail = storedEmail
        currentPhone = storedPhone
        nickname = defaults.string(forKey: Keys.nickname) ?? "用户123"
        return nil
    }

    @discardableResult
    func loginWithProvider(_ provider: SocialProvider, identifier: String) -> String? {
        guard !identifier.isEmpty else {
            return "auth.provider_failed"
        }

        defaults.set(provider.rawValue, forKey: Keys.provider)
        defaults.set(identifier, forKey: Keys.providerID)
        defaults.set(true, forKey: Keys.isLoggedIn)
        defaults.set(Date(), forKey: Keys.lastActiveAt)

        if defaults.string(forKey: Keys.nickname)?.isEmpty != false {
            let providerName: String
            switch provider {
            case .wechat: providerName = "微信用户"
            case .qq: providerName = "QQ用户"
            case .apple: providerName = "Apple用户"
            }
            defaults.set(providerName, forKey: Keys.nickname)
        }

        currentProvider = provider
        nickname = defaults.string(forKey: Keys.nickname) ?? "用户123"
        hasAccount = true
        isAuthenticated = true
        return nil
    }

    func logout() {
        defaults.set(false, forKey: Keys.isLoggedIn)
        isAuthenticated = false
    }

    @discardableResult
    func updateNickname(_ newNickname: String) -> String? {
        let trimmed = newNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "auth.nickname_empty"
        }
        defaults.set(trimmed, forKey: Keys.nickname)
        nickname = trimmed
        return nil
    }

    @discardableResult
    func updateEmail(newEmail: String, password: String) -> String? {
        let normalizedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            return "auth.email_empty"
        }
        guard isValidEmail(normalizedEmail) else {
            return "auth.invalid_email"
        }
        guard verify(password: password) else {
            return "auth.current_password_wrong"
        }

        defaults.set(normalizedEmail, forKey: Keys.email)
        currentEmail = normalizedEmail
        return nil
    }

    @discardableResult
    func updatePhone(newPhone: String, password: String) -> String? {
        let normalizedPhone = normalizePhone(newPhone)
        guard !normalizedPhone.isEmpty else {
            return "auth.phone_empty"
        }
        guard isValidPhone(normalizedPhone) else {
            return "auth.invalid_phone"
        }
        guard verify(password: password) else {
            return "auth.current_password_wrong"
        }

        defaults.set(normalizedPhone, forKey: Keys.phone)
        currentPhone = normalizedPhone
        return nil
    }

    @discardableResult
    func updatePassword(currentPassword: String, newPassword: String, confirmPassword: String) -> String? {
        guard verify(password: currentPassword) else {
            return "auth.current_password_wrong"
        }
        guard newPassword.count >= 6 else {
            return "auth.password_too_short"
        }
        guard newPassword == confirmPassword else {
            return "auth.password_not_match"
        }
        guard currentPassword != newPassword else {
            return "auth.password_same"
        }

        let salt = UUID().uuidString
        let hash = Self.hash(password: newPassword, salt: salt)
        defaults.set(salt, forKey: Keys.passwordSalt)
        defaults.set(hash, forKey: Keys.passwordHash)
        return nil
    }

    @discardableResult
    func resetPassword(
        email: String,
        phone: String,
        fieldType: LoginFieldType,
        newPassword: String,
        confirmPassword: String
    ) -> String? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPhone = normalizePhone(phone)
        let storedEmail = defaults.string(forKey: Keys.email)?.lowercased() ?? ""
        let storedPhone = defaults.string(forKey: Keys.phone) ?? ""

        if fieldType == .email {
            guard normalizedEmail == storedEmail, !normalizedEmail.isEmpty else {
                return "auth.reset_account_not_match"
            }
        } else {
            guard normalizedPhone == storedPhone, !normalizedPhone.isEmpty else {
                return "auth.reset_account_not_match"
            }
        }

        guard newPassword.count >= 6 else {
            return "auth.password_too_short"
        }
        guard newPassword == confirmPassword else {
            return "auth.password_not_match"
        }

        let salt = UUID().uuidString
        let hash = Self.hash(password: newPassword, salt: salt)
        defaults.set(salt, forKey: Keys.passwordSalt)
        defaults.set(hash, forKey: Keys.passwordHash)
        defaults.set(false, forKey: Keys.isLoggedIn)
        isAuthenticated = false
        return nil
    }

    private func touch() {
        defaults.set(Date(), forKey: Keys.lastActiveAt)
    }

    private func verify(password: String) -> Bool {
        guard let storedHash = defaults.string(forKey: Keys.passwordHash),
              let salt = defaults.string(forKey: Keys.passwordSalt) else {
            return false
        }
        return Self.hash(password: password, salt: salt) == storedHash
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func isValidPhone(_ phone: String) -> Bool {
        let pattern = #"^1[3-9]\d{9}$"#
        return phone.range(of: pattern, options: .regularExpression) != nil
    }

    private func normalizePhone(_ phone: String) -> String {
        phone.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private static func hash(password: String, salt: String) -> String {
        let payload = "\(salt)|\(password)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
