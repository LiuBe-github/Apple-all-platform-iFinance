//
//  ImageCache.swift
//  iFinance
//
//  图片缓存（内存 + 磁盘 双层缓存）
//

import UIKit

/// 图片缓存（内存 + 磁盘 双层缓存）
final class ImageCache {
    static let shared = ImageCache()

    /// 内存缓存（NSCache，系统在内存压力时自动清理）
    private let memoryCache = NSCache<NSString, UIImage>()

    /// 磁盘缓存目录
    private let diskDirectory: URL

    /// 磁盘缓存有效期：7 天
    private let diskExpiry: TimeInterval = 7 * 24 * 60 * 60

    /// 正在进行的请求（防止重复请求同一URL）
    private var inflightTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {
        memoryCache.countLimit = 30
        memoryCache.totalCostLimit = 80 * 1024 * 1024 // 80 MB

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskDirectory = caches.appendingPathComponent("iFinance/ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)

        // 启动时清理过期文件
        cleanupExpiredDiskCache()
    }

    // MARK: - 内存缓存

    func get(_ key: String) -> UIImage? {
        memoryCache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
    }

    // MARK: - 磁盘缓存

    func getFromDisk(_ key: String) -> UIImage? {
        let url = diskURL(for: key)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < diskExpiry,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        // 回填内存缓存
        set(image, for: key)
        return image
    }

    func saveToDisk(_ image: UIImage, for key: String) {
        guard let data = image.jpegData(compressionQuality: 0.72) else { return }
        let url = diskURL(for: key)
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - 请求去重

    func setInflightTask(_ task: Task<UIImage?, Never>, forKey key: String) {
        inflightTasks[key] = task
    }

    func getInflightTask(forKey key: String) -> Task<UIImage?, Never>? {
        inflightTasks[key]
    }

    func removeInflightTask(forKey key: String) {
        inflightTasks.removeValue(forKey: key)
    }

    // MARK: - 辅助

    private func diskURL(for key: String) -> URL {
        let hash = key.utf8.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent("\(hash).jpg")
    }

    private func cleanupExpiredDiskCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: self.diskDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }

            let now = Date()
            for file in files {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let modified = attrs[.modificationDate] as? Date,
                   now.timeIntervalSince(modified) > self.diskExpiry {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
}
