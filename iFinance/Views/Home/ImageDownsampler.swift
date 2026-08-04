//
//  ImageDownsampler.swift
//  iFinance
//
//  图片降采样工具
//

import UIKit

/// 图片降采样工具
enum ImageDownsampler {
    /// 将图片降采样到目标尺寸（保持宽高比）
    /// 目标尺寸设为屏幕密度的 1x 即可，因为 displayScale 由上层处理
    static func downsample(_ imageData: Data, to maxSize: CGSize) -> UIImage? {
        let imageSourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions as CFDictionary) else { return nil }

        // 解码时直接降采样到目标尺寸
        let maxDimension = max(maxSize.width, maxSize.height)
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
