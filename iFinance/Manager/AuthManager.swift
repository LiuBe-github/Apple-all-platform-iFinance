//
//  AuthManager.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/25.
//

import Foundation
import Combine
import CryptoKit
import AuthenticationServices
internal import CoreData

/// 认证管理器
/// 账号凭证（密码哈希/盐）存储在 Core Data UserProfile 中，支持多账号
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

    /// 当前登录用户的Core Data记录
    @Published private(set) var currentUser: UserProfile?

    /// 头像数据（@Published，确保视图监听变化）
    @Published private(set) var avatarData: Data?

    // MARK: - 计算属性（从currentUser读取）

    var userIdentifier: String {
        currentUser?.userIdentifier ?? "anonymous"
    }

    var nickname: String {
        currentUser?.nickname ?? "用户123"
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
        // 供 FetchRequest 使用
        static let userIdentifier      = "AuthUserIdentifier"
    }

    // MARK: - 初始化

    private init() {
        bootstrap()
    }

    // MARK: - 调试：打印所有用户信息

    /// 每次启动时输出 Core Data 中所有账号（仅调试用）
    private func debugPrintAllUsers() {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        guard let profiles = try? context.fetch(request), !profiles.isEmpty else {
            print("📋 [AuthManager] 当前没有任何注册账号")
            return
        }

        print("📋 [AuthManager] ===== 启动时账号概览 (\(profiles.count) 个) =====")
        for (index, profile) in profiles.enumerated() {
            let identifier = profile.userIdentifier ?? "anonymous"
            let email = profile.email ?? "—"
            let phone = profile.phone ?? "—"
            let hash = profile.passwordHash ?? "—"
            let currentMarker = profile.id == currentUser?.id ? " ◀ 当前登录" : ""
            print("""
                【账号 \(index + 1)】
                 identifier  : \(identifier)
                 email       : \(email)
                 phone       : \(phone)
                 passwordHash: \(hash)\(currentMarker)
                """)
        }
        print("==========================================")
    }

    // MARK: - bootstrap

    func bootstrap() {
        let context = PersistenceController.shared.container.viewContext

        // 尝试将旧版 UserDefaults 凭证迁移到 Core Data
        migrateLegacyCredentialsIfNeeded(context: context)

        let loggedIn = defaults.bool(forKey: UDKeys.isLoggedIn)
        guard loggedIn else {
            isAuthenticated = false
            currentUser = nil
            avatarData = nil
            debugPrintAllUsers()
            return
        }

        let now = Date()
        let lastActive = defaults.object(forKey: UDKeys.lastActiveAt) as? Date ?? .distantPast
        if now.timeIntervalSince(lastActive) > sessionLifetime {
            logout()
            return
        }

        // 恢复上次登录的用户
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

        debugPrintAllUsers()
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

        let context = PersistenceController.shared.container.viewContext

        // 确定 userIdentifier：邮箱优先，否则手机号
        let identifier = fieldType == .email ? normalizedEmail : normalizedPhone

        // 检查是否已存在该账号
        if fetchUserProfile(identifier: identifier, context: context) != nil {
            return "auth.account_exists"
        }

        // 创建新 UserProfile
        let salt = UUID().uuidString
        let hash = Self.hashPassword(password: password, salt: salt)

        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.userIdentifier = identifier
        profile.email = normalizedEmail.isEmpty ? nil : normalizedEmail
        profile.phone = normalizedPhone.isEmpty ? nil : normalizedPhone
        profile.passwordHash = hash
        profile.passwordSalt = salt
        profile.nickname = "用户\(Int.random(in: 100...999))"
        profile.monthlyBudget = 3000
        profile.createdAt = Date()
        profile.updatedAt = Date()

        do {
            try context.save()
        } catch {
            return "auth.save_failed"
        }

        // 登录
        signIn(profile: profile)
        return nil
    }

    // MARK: - 登录（邮箱/手机号+密码）

    @discardableResult
    func login(email: String, phone: String, password: String, fieldType: LoginFieldType) -> String? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPhone = normalizePhone(phone)

        let context = PersistenceController.shared.container.viewContext

        // 查询匹配的 UserProfile
        let identifier = fieldType == .email ? normalizedEmail : normalizedPhone
        guard let profile = fetchUserProfile(identifier: identifier, context: context) else {
            // 也尝试用邮箱/手机号字段匹配（账号 identifier 可能是另一个）
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

        let context = PersistenceController.shared.container.viewContext

        // 查找或创建 UserProfile
        let profile: UserProfile
        if let existing = fetchUserProfile(identifier: identifier, context: context) {
            profile = existing
        } else {
            let p = UserProfile(context: context)
            p.id = UUID()
            p.userIdentifier = identifier
            p.provider = provider.rawValue
            p.providerID = identifier
            p.nickname = {
                switch provider {
                case .wechat: return "微信用户"
                case .qq:     return "QQ用户"
                case .apple:  return "Apple用户"
                }
            }()
            p.monthlyBudget = 3000
            p.createdAt = Date()
            p.updatedAt = Date()
            try? context.save()
            profile = p
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
                    // 补充设置昵称
                    if currentUser?.nickname == "Apple用户" || currentUser?.nickname == nil {
                        currentUser?.nickname = displayName
                        try? PersistenceController.shared.container.viewContext.save()
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

        let context = PersistenceController.shared.container.viewContext
        let identifier = user.userIdentifier ?? "anonymous"

        // 1. 删除该用户的所有账单
        let billRequest: NSFetchRequest<NSFetchRequestResult> = Bill.fetchRequest()
        billRequest.predicate = NSPredicate(format: "createdBy == %@", identifier)
        let billDeleteRequest = NSBatchDeleteRequest(fetchRequest: billRequest)
        try? context.execute(billDeleteRequest)

        // 2. 删除 UserProfile 记录
        context.delete(user)
        try? context.save()

        // 3. 登出
        logout()
    }

    // MARK: - 删除所有账号（调试用）

    /// 清空 Core Data 中所有 UserProfile 和所有 Bill（不可恢复）
    func deleteAllAccounts() {
        let context = PersistenceController.shared.container.viewContext

        // 删除所有账单
        let billRequest: NSFetchRequest<NSFetchRequestResult> = Bill.fetchRequest()
        let billDelete = NSBatchDeleteRequest(fetchRequest: billRequest)
        try? context.execute(billDelete)

        // 删除所有用户
        let userRequest: NSFetchRequest<NSFetchRequestResult> = UserProfile.fetchRequest()
        let userDelete = NSBatchDeleteRequest(fetchRequest: userRequest)
        try? context.execute(userDelete)

        try? context.save()

        // 登出当前
        logout()

        print("✅ [AuthManager] 已删除所有账号和账单")
    }

    // MARK: - 更新资料

    @discardableResult
    func updateNickname(_ newNickname: String) -> String? {
        let trimmed = newNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "auth.nickname_empty" }
        guard let user = currentUser else { return nil }
        user.nickname = trimmed
        user.updatedAt = Date()
        try? PersistenceController.shared.container.viewContext.save()
        objectWillChange.send()
        return nil
    }

    func updateAvatar(_ data: Data) {
        guard let user = currentUser else { return }
        user.avatarData = data
        user.updatedAt = Date()
        try? PersistenceController.shared.container.viewContext.save()
        avatarData = data
    }

    func updateMonthlyBudget(_ amount: Double) {
        guard let user = currentUser else { return }
        user.monthlyBudget = amount
        user.updatedAt = Date()
        try? PersistenceController.shared.container.viewContext.save()
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
        try? PersistenceController.shared.container.viewContext.save()
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
        try? PersistenceController.shared.container.viewContext.save()
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
        try? PersistenceController.shared.container.viewContext.save()
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

        let context = PersistenceController.shared.container.viewContext
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

    private func fetchUserProfile(identifier: String, context: NSManagedObjectContext) -> UserProfile? {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "userIdentifier == %@", identifier)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func findProfileByContact(email: String?, phone: String?, context: NSManagedObjectContext) -> UserProfile? {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        if let email = email, !email.isEmpty {
            request.predicate = NSPredicate(format: "email == %@", email)
        } else if let phone = phone, !phone.isEmpty {
            request.predicate = NSPredicate(format: "phone == %@", phone)
        } else {
            return nil
        }
        request.fetchLimit = 1
        return try? context.fetch(request).first
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

    private func migrateLegacyCredentialsIfNeeded(context: NSManagedObjectContext) {
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

        // 如果 Core Data 中已经有这个账号就不重复迁移
        if fetchUserProfile(identifier: identifier, context: context) != nil { return }

        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.userIdentifier = identifier
        profile.email = legacyEmail.isEmpty ? nil : legacyEmail
        profile.phone = legacyPhone.isEmpty ? nil : legacyPhone
        profile.passwordHash = legacyHash
        profile.passwordSalt = legacySalt
        profile.nickname = legacyNickname ?? "用户\(Int.random(in: 100...999))"
        profile.provider = legacyProvider
        profile.providerID = legacyProviderID
        profile.monthlyBudget = 3000
        profile.createdAt = Date()
        profile.updatedAt = Date()
        try? context.save()

        // 清除旧版 UserDefaults 凭证，避免重复迁移
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

    static func hashPassword(password: String, salt: String) -> String {
        let payload = "\(salt)|\(password)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
