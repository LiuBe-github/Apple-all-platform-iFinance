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
    private var cachedThumbnail: UIImage?
    private var cachedThumbnailHash: Int?
    private var cachedThumbnailDiameter: CGFloat?

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

    /// 圆形缩略图（标签栏等小尺寸场景）：**按等比例填充后在离屏渲染成固定点尺寸的位图**。
    /// 注意：切图必须是固定尺寸位图，不能返回 `resizable()` 的 `Image`——
    /// `TabView` 的 `.tabItem` 里没有固有尺寸的可伸缩图片会被拉伸铺满标签栏。
    func thumbnail(for data: Data?, diameter: CGFloat) -> UIImage? {
        guard let data, let image = image(for: data) else { return nil }
        // 尺寸为 0 时 aspect fill 会算出 inf/nan，直接回落默认头像
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        let hash = data.hashValue
        if hash == cachedThumbnailHash, cachedThumbnailDiameter == diameter, let cachedThumbnail {
            return cachedThumbnail
        }

        let size = CGSize(width: diameter, height: diameter)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false

        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()

            // 等比例填充（aspect fill）后居中绘制
            let ratio = max(size.width / image.size.width, size.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let origin = CGPoint(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }

        // 标签栏会把非符号图片当模板填充（整块纯色）——在 UIImage 层标记保持原色
        let original = rendered.withRenderingMode(.alwaysOriginal)
        cachedThumbnail = original
        cachedThumbnailHash = hash
        cachedThumbnailDiameter = diameter
        return original
    }
}
