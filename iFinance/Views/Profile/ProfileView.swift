//
//  ProfileAndSetting.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/13.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @State private var nickname: String = UserDefaults.standard.string(forKey: "UserProfileNickname") ?? "用户123"
    @State private var avatarImage: Image? = nil
    @State private var selectedAvatar: PhotosPickerItem? = nil
    
    // 用于监听昵称变化并保存
    private let nicknameDefaultsKey = "UserProfileNickname"
    private let avatarImageDataKey = "UserProfileAvatarData"
    
    var body: some View {
        NavigationStack {
            Form {
                // 头像和昵称（居中）
                Section {
                    VStack(spacing: 16) {
                        // 头像（圆形 + 可点击）
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
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                
                // 其他设置项
                Section("账户") {
                    NavigationLink("修改昵称") {
                        TextField("请输入新昵称", text: $nickname)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                            .onDisappear {
                                // 保存昵称到 UserDefaults
                                UserDefaults.standard.set(self.nickname, forKey: nicknameDefaultsKey)
                            }
                    }
                    NavigationLink("绑定手机号") { Text("功能开发中") }
                    NavigationLink("第三方账号") { Text("功能开发中") }
                    NavigationLink("绑定点击邮箱") { Text("功能开发中") }
                    NavigationLink("修改密码") { Text("功能开发中") }
                }
            }
            .navigationTitle("个人设置")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadPersistedAvatar()
            }
            .onChange(of: selectedAvatar) { _, newItem in
                Task {
                    if let newItem = newItem {
                        await saveAvatar(from: newItem)
                    }
                }
            }
            .onChange(of: nickname) { _, newNickname in
                // 实时保存昵称（可选，也可只在 onDisappear 时保存）
                UserDefaults.standard.set(newNickname, forKey: nicknameDefaultsKey)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - 持久化：加载头像
    private func loadPersistedAvatar() {
        if let imageData = UserDefaults.standard.data(forKey: avatarImageDataKey),
           let uiImage = UIImage(data: imageData) {
            avatarImage = Image(uiImage: uiImage)
        } else {
            avatarImage = nil // 使用默认图标
        }
    }
    
    // MARK: - 持久化：保存头像
    private func saveAvatar(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            return
        }
        
        // 缩小图片尺寸以节省存储（可选）
        let resizedImage = resizeImage(uiImage, targetSize: CGSize(width: 300, height: 300))
        
        // 转为 Data 并保存
        if let imageData = resizedImage.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(imageData, forKey: avatarImageDataKey)
            await MainActor.run {
                avatarImage = Image(uiImage: resizedImage)
            }
        }
    }
    
    // MARK: - 工具：缩放图片
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

#Preview {
    ProfileView()
}
