//
//  AuthManager.swift
//  iFinanceSwiftData
//
//  SwiftData 版认证管理器。
//  对外 API 与 Core Data 版完全一致（视图代码零改动复用），内部改为 SwiftData 查询。
//  账号凭证（密码哈希 / 盐）存储在 SwiftData 的 UserProfile 中，支持多账号。
//

import Foundation
import Combine
import CryptoKit
import AuthenticationServices
import SwiftData

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    // MARK: - 登录类型

    enum LoginFieldType {
        case email
        case phone
    }

    enum SocialProvider: String {
        case wechat
        case qq
        case apple
    }

    // MARK: - Published 状态

    @Published private(set) var isAuthenticated = false
    @Published private(set) var hasAccount = false
    @Published private(set) var currentEmail = ""
    @Published private(set) var currentPhone = ""
    @Published private(set) var currentProvider: SocialProvider?

    /// 当前登录用户的 SwiftData 记录
    @Published private(set) var currentUser: UserProfile?

    /// 头像数据（@Published，确保视图监听变化）
    @Published private(set) var avatarData: Data?

    // MARK: - 计算属性（从 currentUser 读取）

    var userIdentifier: String {
        currentUser?.userIdentifier ?? "anonymous"
    }

    var nickname: String {
        currentUser?.nickname ?? "用户123"
    }

    /// 个性签名（未设置时为空串）
    var signature: String {
        currentUser?.signature ?? ""
    }

    /// 个性签名最大长度
    nonisolated static let signatureMaxLength = 40

    /// 个性签名的校验结果
    enum SignatureValidation: Equatable {
        /// 合法值（nil 表示清空签名）
        case valid(String?)
        /// 超出长度限制
        case tooLong
    }

    /// 校验并规范化个性签名（去掉首尾空白；空串表示清空）
    nonisolated static func validateSignature(_ raw: String) -> SignatureValidation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= signatureMaxLength else { return .tooLong }
        return .valid(trimmed.isEmpty ? nil : trimmed)
    }

    var monthlyBudget: Double {
        currentUser?.monthlyBudget ?? 3000
    }

    // MARK: - 私有属性

    private let defaults = UserDefaults.standard
    private let sessionLifetime: TimeInterval = 7 * 24 * 60 * 60

    private enum UDKeys {
        static let lastLoginIdentifier = "AuthLastLoginIdentifier"
        static let isLoggedIn          = "AuthIsLoggedIn"
        static let lastActiveAt        = "AuthLastActiveAt"
        // 向下兼容老版本 UserDefaults 凭证迁移
        static let legacyEmail         = "AuthEmail"
        static let legacyPhone         = "AuthPhone"
        static let legacyHash          = "AuthPasswordHash"
        static let legacySalt          = "AuthPasswordSalt"
        static let legacyProvider      = "AuthProvider"
        static let legacyProviderID    = "AuthProviderID"
        static let legacyNickname      = "UserProfileNickname"
        // 供查询 / SwiftData 过滤使用
        static let userIdentifier      = "AuthUserIdentifier"
    }

    private var context: ModelContext {
        PersistenceController.shared.container.mainContext
    }

    // MARK: - 初始化

    private init() {
        bootstrap()
    }

    // MARK: - bootstrap

    func bootstrap() {
        let context = self.context

        // 尝试将旧版 UserDefaults 凭证迁移到 SwiftData
        migrateLegacyCredentialsIfNeeded(context: context)

        let loggedIn = defaults.bool(forKey: UDKeys.isLoggedIn)
        guard loggedIn else {
            isAuthenticated = false
            currentUser = nil
            avatarData = nil
            return
        }

        let now = Date()
        let lastActive = defaults.object(forKey: UDKeys.lastActiveAt) as? Date ?? .distantPast
        if now.timeIntervalSince(lastActive) > sessionLifetime {
            logout()
            return
        }

        if let identifier = defaults.string(forKey: UDKeys.lastLoginIdentifier) {
            currentUser = fetchUserProfile(identifier: identifier, context: context)
        }

        if let user = currentUser {
            currentEmail = user.email ?? ""
            currentPhone = user.phone ?? ""
            avatarData = user.avatarData
            if let providerRaw = user.provider {
                currentProvider = SocialProvider(rawValue: providerRaw)
            }
            hasAccount = true
            isAuthenticated = true
            syncUserIdentifierToDefaults()
            touch()
        } else {
            logout()
        }
    }

    func handleAppDidBecomeActive() {
        bootstrap()
        if isAuthenticated { touch() }
    }

    func handleAppWillResignActive() {
        if isAuthenticated { touch() }
    }

    // MARK: - 注册

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
            guard isValidEmail(normalizedEmail) else { return "auth.invalid_email" }
        } else {
            guard isValidPhone(normalizedPhone) else { return "auth.invalid_phone" }
        }
        guard password.count >= 6 else { return "auth.password_too_short" }
        guard password == confirmPassword else { return "auth.password_not_match" }

        let context = self.context
        let identifier = fieldType == .email ? normalizedEmail : normalizedPhone

        if fetchUserProfile(identifier: identifier, context: context) != nil {
            return "auth.account_exists"
        }

        let salt = UUID().uuidString
        let hash = Self.hashPassword(password: password, salt: salt)

        let profile = UserProfile(
            userIdentifier: identifier,
            email: normalizedEmail.isEmpty ? nil : normalizedEmail,
            phone: normalizedPhone.isEmpty ? nil : normalizedPhone,
            passwordHash: hash,
            passwordSalt: salt,
            nickname: "用户\(Int.random(in: 100...999))",
            monthlyBudget: 3000
        )
        context.insert(profile)

        do {
            try context.save()
        } catch {
            return "auth.save_failed"
        }

        signIn(profile: profile)
        return nil
    }

    // MARK: - 登录（邮箱/手机号+密码）

    @discardableResult
    func login(email: String, phone: String, password: String, fieldType: LoginFieldType) -> String? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPhone = normalizePhone(phone)
        let context = self.context

        let identifier = fieldType == .email ? normalizedEmail : normalizedPhone
        guard let profile = fetchUserProfile(identifier: identifier, context: context) else {
            let found = findProfileByContact(
                email: fieldType == .email ? normalizedEmail : nil,
                phone: fieldType == .phone ? normalizedPhone : nil,
                context: context
            )
            guard let found else { return "auth.no_account" }
            return verifyAndSignIn(profile: found, password: password)
        }

        return verifyAndSignIn(profile: profile, password: password)
    }

    // MARK: - 第三方登录

    @discardableResult
    func loginWithProvider(_ provider: SocialProvider, identifier: String) -> String? {
        guard !identifier.isEmpty else { return "auth.provider_failed" }

        let context = self.context
        let profile: UserProfile
        if let existing = fetchUserProfile(identifier: identifier, context: context) {
            profile = existing
        } else {
            let nickname: String
            switch provider {
            case .wechat: nickname = "微信用户"
            case .qq:     nickname = "QQ用户"
            case .apple:  nickname = "Apple用户"
            }
            let created = UserProfile(
                userIdentifier: identifier,
                provider: provider.rawValue,
                providerID: identifier,
                nickname: nickname,
                monthlyBudget: 3000
            )
            context.insert(created)
            try? context.save()
            profile = created
        }

        signIn(profile: profile)
        return nil
    }

    // MARK: - Sign in with Apple

    @discardableResult
    func handleSignInWithApple(result: Result<ASAuthorization, Error>) -> String? {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return "auth.apple_failed"
            }
            let appleID = appleIDCredential.user

            var displayName = "Apple用户"
            if let fullName = appleIDCredential.fullName {
                let given  = fullName.givenName  ?? ""
                let family = fullName.familyName ?? ""
                let combined = "\(family)\(given)".trimmingCharacters(in: .whitespaces)
                if !combined.isEmpty { displayName = combined }
            }

            return loginWithProvider(.apple, identifier: appleID)
                .map { _ in "auth.apple_failed" } ?? {
                    if currentUser?.nickname == "Apple用户" || currentUser?.nickname == nil {
                        currentUser?.nickname = displayName
                        try? self.context.save()
                    }
                    return nil
                }()

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return nil }
            return "auth.apple_failed"
        }
    }

    // MARK: - 登出

    func logout() {
        defaults.set(false, forKey: UDKeys.isLoggedIn)
        defaults.removeObject(forKey: UDKeys.lastLoginIdentifier)
        defaults.removeObject(forKey: UDKeys.userIdentifier)
        isAuthenticated = false
        currentUser = nil
        avatarData = nil
        currentEmail = ""
        currentPhone = ""
        currentProvider = nil
        hasAccount = false
    }

    // MARK: - 注销账号（删除本人所有数据）

    /// 删除当前账号的所有账单和 UserProfile 记录，注销后自动登出
    func deleteAccount() {
        guard let user = currentUser else { return }

        let context = self.context
        let identifier = user.userIdentifier ?? "anonymous"
        let billPredicate = PersistenceController.billPredicate(for: identifier)

        try? context.delete(model: Bill.self, where: billPredicate)
        context.delete(user)
        try? context.save()

        logout()
    }

    // MARK: - 删除所有账号（调试用）

    /// 清空 SwiftData 中所有 UserProfile 和所有 Bill（不可恢复）
    func deleteAllAccounts() {
        let context = self.context
        try? context.delete(model: Bill.self)
        try? context.delete(model: UserProfile.self)
        try? context.save()
        logout()
        print("✅ [AuthManager-SwiftData] 已删除所有账号和账单")
    }

    // MARK: - 更新资料

    @discardableResult
    func updateNickname(_ newNickname: String) -> String? {
        let trimmed = newNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "auth.nickname_empty" }
        guard let user = currentUser else { return nil }
        user.nickname = trimmed
        user.updatedAt = Date()
        try? context.save()
        objectWillChange.send()
        return nil
    }

    /// 更新个性签名（空串表示清空；超长返回本地化错误 key）
    @discardableResult
    func updateSignature(_ newSignature: String) -> String? {
        switch Self.validateSignature(newSignature) {
        case .tooLong:
            return "profile.signature_too_long"
        case .valid(let value):
            guard let user = currentUser else { return nil }
            user.signature = value
            user.updatedAt = Date()
            try? context.save()
            objectWillChange.send()
            return nil
        }
    }

    func updateAvatar(_ data: Data) {
        guard let user = currentUser else { return }
        user.avatarData = data
        user.updatedAt = Date()
        try? context.save()
        avatarData = data
    }

    func updateMonthlyBudget(_ amount: Double) {
        guard let user = currentUser else { return }
        user.monthlyBudget = amount
        user.updatedAt = Date()
        try? context.save()
        objectWillChange.send()
    }

    @discardableResult
    func updateEmail(newEmail: String, password: String) -> String? {
        let normalized = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return "auth.email_empty" }
        guard isValidEmail(normalized) else { return "auth.invalid_email" }
        guard verify(password: password) else { return "auth.current_password_wrong" }
        guard let user = currentUser else { return nil }
        user.email = normalized
        user.updatedAt = Date()
        currentEmail = normalized
        try? context.save()
        return nil
    }

    @discardableResult
    func updatePhone(newPhone: String, password: String) -> String? {
        let normalized = normalizePhone(newPhone)
        guard !normalized.isEmpty else { return "auth.phone_empty" }
        guard isValidPhone(normalized) else { return "auth.invalid_phone" }
        guard verify(password: password) else { return "auth.current_password_wrong" }
        guard let user = currentUser else { return nil }
        user.phone = normalized
        user.updatedAt = Date()
        currentPhone = normalized
        try? context.save()
        return nil
    }

    @discardableResult
    func updatePassword(currentPassword: String, newPassword: String, confirmPassword: String) -> String? {
        guard verify(password: currentPassword) else { return "auth.current_password_wrong" }
        guard newPassword.count >= 6 else { return "auth.password_too_short" }
        guard newPassword == confirmPassword else { return "auth.password_not_match" }
        guard currentPassword != newPassword else { return "auth.password_same" }
        guard let user = currentUser else { return nil }
        let salt = UUID().uuidString
        user.passwordSalt = salt
        user.passwordHash = Self.hashPassword(password: newPassword, salt: salt)
        user.updatedAt = Date()
        try? context.save()
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
        guard newPassword.count >= 6 else { return "auth.password_too_short" }
        guard newPassword == confirmPassword else { return "auth.password_not_match" }

        let context = self.context
        let identifier = fieldType == .email ? normalizedEmail : normalizedPhone
        guard let profile = fetchUserProfile(identifier: identifier, context: context)
                ?? findProfileByContact(
                    email: fieldType == .email ? normalizedEmail : nil,
                    phone: fieldType == .phone ? normalizedPhone : nil,
                    context: context
                )
        else { return "auth.reset_account_not_match" }

        let salt = UUID().uuidString
        profile.passwordSalt = salt
        profile.passwordHash = Self.hashPassword(password: newPassword, salt: salt)
        profile.updatedAt = Date()
        try? context.save()
        logout()
        return nil
    }

    // MARK: - 私有辅助

    private func signIn(profile: UserProfile) {
        currentUser = profile
        avatarData = profile.avatarData
        currentEmail = profile.email ?? ""
        currentPhone = profile.phone ?? ""
        currentProvider = profile.provider.flatMap { SocialProvider(rawValue: $0) }
        hasAccount = true
        isAuthenticated = true
        defaults.set(true, forKey: UDKeys.isLoggedIn)
        defaults.set(Date(), forKey: UDKeys.lastActiveAt)
        defaults.set(profile.userIdentifier, forKey: UDKeys.lastLoginIdentifier)
        syncUserIdentifierToDefaults()
    }

    private func verifyAndSignIn(profile: UserProfile, password: String) -> String? {
        guard let hash = profile.passwordHash,
              let salt = profile.passwordSalt else {
            return "auth.no_account"
        }
        guard Self.hashPassword(password: password, salt: salt) == hash else {
            return "auth.invalid_credentials"
        }
        signIn(profile: profile)
        return nil
    }

    private func fetchUserProfile(identifier: String, context: ModelContext) -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { $0.userIdentifier == identifier }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func findProfileByContact(email: String?, phone: String?, context: ModelContext) -> UserProfile? {
        if let email, !email.isEmpty {
            var descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate<UserProfile> { $0.email == email }
            )
            descriptor.fetchLimit = 1
            return try? context.fetch(descriptor).first
        }
        if let phone, !phone.isEmpty {
            var descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate<UserProfile> { $0.phone == phone }
            )
            descriptor.fetchLimit = 1
            return try? context.fetch(descriptor).first
        }
        return nil
    }

    private func verify(password: String) -> Bool {
        guard let user = currentUser,
              let hash = user.passwordHash,
              let salt = user.passwordSalt else { return false }
        return Self.hashPassword(password: password, salt: salt) == hash
    }

    private func syncUserIdentifierToDefaults() {
        defaults.set(userIdentifier, forKey: UDKeys.userIdentifier)
    }

    private func touch() {
        defaults.set(Date(), forKey: UDKeys.lastActiveAt)
    }

    // MARK: - 老版本 UserDefaults 迁移

    private func migrateLegacyCredentialsIfNeeded(context: ModelContext) {
        guard let legacyHash = defaults.string(forKey: UDKeys.legacyHash),
              let legacySalt = defaults.string(forKey: UDKeys.legacySalt) else { return }

        let legacyEmail    = defaults.string(forKey: UDKeys.legacyEmail) ?? ""
        let legacyPhone    = defaults.string(forKey: UDKeys.legacyPhone) ?? ""
        let legacyNickname = defaults.string(forKey: UDKeys.legacyNickname)
        let legacyProvider = defaults.string(forKey: UDKeys.legacyProvider)
        let legacyProviderID = defaults.string(forKey: UDKeys.legacyProviderID)

        let identifier: String
        if !legacyEmail.isEmpty {
            identifier = legacyEmail
        } else if !legacyPhone.isEmpty {
            identifier = legacyPhone
        } else if let pid = legacyProviderID {
            identifier = pid
        } else {
            return
        }

        if fetchUserProfile(identifier: identifier, context: context) != nil { return }

        let profile = UserProfile(
            userIdentifier: identifier,
            email: legacyEmail.isEmpty ? nil : legacyEmail,
            phone: legacyPhone.isEmpty ? nil : legacyPhone,
            passwordHash: legacyHash,
            passwordSalt: legacySalt,
            provider: legacyProvider,
            providerID: legacyProviderID,
            nickname: legacyNickname ?? "用户\(Int.random(in: 100...999))",
            monthlyBudget: 3000
        )
        context.insert(profile)
        try? context.save()

        defaults.removeObject(forKey: UDKeys.legacyHash)
        defaults.removeObject(forKey: UDKeys.legacySalt)
    }

    // MARK: - 验证/工具

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

    /// 纯函数，无需 MainActor（供测试与其它上下文复用）
    nonisolated static func hashPassword(password: String, salt: String) -> String {
        let payload = "\(salt)|\(password)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
