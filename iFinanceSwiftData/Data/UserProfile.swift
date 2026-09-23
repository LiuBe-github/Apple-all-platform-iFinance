//
//  UserProfile.swift
//  iFinanceSwiftData
//
//  SwiftData 版用户模型（字段与 Core Data 版 UserProfile 实体一一对应）
//

import Foundation
import SwiftData

@Model
final class UserProfile {

    var id: UUID?

    /// 登录标识：小写邮箱 / 归一化手机号 / Apple user id
    var userIdentifier: String?

    var email: String?
    var phone: String?

    /// 密码哈希与盐（第三方登录账号为空）
    var passwordHash: String?
    var passwordSalt: String?

    /// 第三方登录信息："wechat" / "qq" / "apple"
    var provider: String?
    var providerID: String?

    var nickname: String?

    /// 头像（外部存储，避免撑大主库）
    @Attribute(.externalStorage) var avatarData: Data?

    /// 月度预算
    var monthlyBudget: Double = 3000

    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: UUID? = UUID(),
        userIdentifier: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        passwordHash: String? = nil,
        passwordSalt: String? = nil,
        provider: String? = nil,
        providerID: String? = nil,
        nickname: String? = nil,
        avatarData: Data? = nil,
        monthlyBudget: Double = 3000,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.userIdentifier = userIdentifier
        self.email = email
        self.phone = phone
        self.passwordHash = passwordHash
        self.passwordSalt = passwordSalt
        self.provider = provider
        self.providerID = providerID
        self.nickname = nickname
        self.avatarData = avatarData
        self.monthlyBudget = monthlyBudget
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

