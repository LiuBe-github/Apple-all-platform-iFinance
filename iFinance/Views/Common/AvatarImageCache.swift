//
//  AvatarImageCache.swift
//  iFinance
//
//  头像解码缓存：`UIImage(data:)` 每次渲染都解码会有明显开销，
//  这里按数据哈希缓存最近一张头像，供导航栏 / 设置页 / 个人中心复用。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import UIKit

@MainActor
final class AvatarImageCache {
    static let shared = AvatarImageCache()

    private var cachedHash: Int?
    private var cachedImage: UIImage?

    func image(for data: Data?) -> UIImage? {
        guard let data else { return nil }

        let hash = data.hashValue
        if hash == cachedHash, let cachedImage {
            return cachedImage
        }

        guard let image = UIImage(data: data) else { return nil }
        cachedHash = hash
        cachedImage = image
        return image
    }
}
