//
//  ImageLoader.swift
//  iFinance
//
//  图片加载器
//

import UIKit
import Combine

/// 图片加载器
@MainActor
final class ImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoaded: Bool = false

    /// 当前加载的URL（用于防竞态）
    private var currentURL: URL?

    /// 目标显示尺寸（用于降采样）
    private var targetSize: CGSize = CGSize(width: 400, height: 560)

    func load(url: URL, targetSize: CGSize = CGSize(width: 400, height: 560)) {
        self.targetSize = targetSize
        let key = url.absoluteString

        // 1️⃣ 内存缓存命中 → 直接返回
        if let cached = ImageCache.shared.get(key) {
            self.image = cached
            self.isLoaded = true
            return
        }

        // 2️⃣ 磁盘缓存命中 → 回填内存并返回
        if let diskCached = ImageCache.shared.getFromDisk(key) {
            self.image = diskCached
            self.isLoaded = true
            return
        }

        // 3️⃣ 检查是否有正在进行的相同请求（请求去重）
        if let existingTask = ImageCache.shared.getInflightTask(forKey: key) {
            currentURL = url
            Task {
                if let result = await existingTask.value {
                    guard url == currentURL else { return }
                    self.image = result
                    self.isLoaded = true
                }
            }
            return
        }

        // 4️⃣ 发起网络请求（带超时 + 降采样）
        currentURL = url
        let task = Task<UIImage?, Never> {
            await performDownload(url: url, key: key)
        }
        ImageCache.shared.setInflightTask(task, forKey: key)

        Task {
            let result = await task.value
            ImageCache.shared.removeInflightTask(forKey: key)
            guard url == currentURL else { return } // 防止旧结果覆盖新请求

            if let img = result {
                self.image = img
            }
            self.isLoaded = true
        }
    }

    // MARK: - 核心下载逻辑

    private func performDownload(url: URL, key: String) async -> UIImage? {
        do {
            // 配置 URLSession：10 秒超时
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForResource = 10
            config.timeoutIntervalForRequest = 8
            config.urlCache = nil // 不使用系统的 URL 缓存，我们自己管理
            let session = URLSession(configuration: config)

            let (data, response) = try await session.data(from: url)

            // 检查 HTTP 状态码
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // 降采样：从大图直接解码为小图（节省 90%+ 内存）
            if let downsampled = ImageDownsampler.downsample(data, to: targetSize) {
                // 写入双层缓存
                ImageCache.shared.set(downsampled, for: key)
                ImageCache.shared.saveToDisk(downsampled, for: key)
                return downsampled
            }
            return nil
        } catch {
            return nil
        }
    }

    /// 预加载（供下一条卡片预加载使用）—— 使用较小的目标尺寸以节省资源
    func preload(url: URL) async {
        let key = url.absoluteString
        guard ImageCache.shared.get(key) == nil,
              ImageCache.shared.getFromDisk(key) == nil else { return }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config)

        guard let (data, _) = try? await session.data(from: url),
              let downsampled = ImageDownsampler.downsample(data, to: CGSize(width: 300, height: 420))
        else { return }

        ImageCache.shared.set(downsampled, for: key)
        ImageCache.shared.saveToDisk(downsampled, for: key)
    }
}
