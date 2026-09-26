//
//  AvatarThumbnailTests.swift
//  iFinanceTests
//
//  回归：标签栏头像必须是「固定**点**尺寸的圆形位图」。
//  曾经在 `.tabItem` 里直接放 `Image(uiImage:).resizable()`——没有固有尺寸的可伸缩图片
//  会被 TabView 拉伸铺满整个标签栏，这里用测试锁住这个约束。
//

import XCTest
import UIKit
@testable import iFinanceSwiftData

@MainActor
final class AvatarThumbnailTests: XCTestCase {

    /// 造一张非正方形（600×300）的测试头像，确保缩略图走的是「等比例填充 + 居中裁圆」
    private func makeAvatarData(width: CGFloat = 600, height: CGFloat = 300) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }

    func testThumbnailHasFixedPointSize() {
        let diameter = AppLayout.tabBarIcon
        let thumbnail = AvatarImageCache.shared.thumbnail(for: makeAvatarData(), diameter: diameter)

        XCTAssertNotNil(thumbnail, "有头像数据时必须能生成缩略图")
        XCTAssertEqual(thumbnail?.size.width ?? 0, diameter, accuracy: 0.01, "点尺寸必须等于传入直径，否则标签栏会拉伸")
        XCTAssertEqual(thumbnail?.size.height ?? 0, diameter, accuracy: 0.01)

        let expectedPixels = Int((diameter * UIScreen.main.scale).rounded())
        XCTAssertEqual(thumbnail?.cgImage?.width ?? 0, expectedPixels, "像素尺寸随屏幕 scale 放大，点尺寸保持固定")

        XCTAssertEqual(
            thumbnail?.renderingMode,
            .alwaysOriginal,
            "标签栏会把非符号图片当模板渲染成纯色块，必须在 UIImage 层标记 alwaysOriginal"
        )
    }

    func testThumbnailIsNilWithoutAvatarData() {
        XCTAssertNil(
            AvatarImageCache.shared.thumbnail(for: nil, diameter: AppLayout.tabBarIcon),
            "无头像时必须返回 nil，让调用方回落到默认人像"
        )
    }

    func testThumbnailFollowsRequestedDiameter() {
        let data = makeAvatarData()
        let small = AvatarImageCache.shared.thumbnail(for: data, diameter: 25)
        let large = AvatarImageCache.shared.thumbnail(for: data, diameter: 56)

        XCTAssertEqual(small?.size.width ?? 0, 25, accuracy: 0.01)
        XCTAssertEqual(large?.size.width ?? 0, 56, accuracy: 0.01, "换尺寸时要重新渲染，不能复用上一次的缓存")
    }
}
