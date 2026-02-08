//
//  UserProfile.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/7.
//

import Foundation
import UIKit

class UserProfile {
    private var username: String = ""
    private var nickname: String = ""
    private var avatar: UIImage? // MARK: 头像用户不选择上传的话，直接调用默认头像，因此要有默认头像的图片资源
    private var email: String?
}

