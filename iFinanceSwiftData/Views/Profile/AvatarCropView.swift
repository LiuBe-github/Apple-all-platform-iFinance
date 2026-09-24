//
//  AvatarCropView.swift
//  iFinance
//
//  头像裁剪：圆形遮罩预览 + 拖动 / 双指缩放，确认后输出 300×300 方形图（展示时裁成圆形）。
//

import SwiftUI

struct AvatarCropView: View {
    let image: UIImage
    var onCancel: () -> Void
    var onConfirm: (UIImage) -> Void

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var side: CGFloat = 0

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 4
    private let outputSide: CGFloat = 300

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let containerSide = max(min(geo.size.width, geo.size.height) - AppSpacing.section * 2, 120)
                ZStack {
                    Color.black.opacity(0.92).ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .frame(width: image.size.width * baseScale(for: containerSide) * zoom,
                               height: image.size.height * baseScale(for: containerSide) * zoom)
                        .offset(offset)
                        .frame(width: containerSide, height: containerSide)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
                        .contentShape(Circle())
                        .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
                        .gesture(dragGesture(side: containerSide))
                        .simultaneousGesture(magnificationGesture(side: containerSide))

                    VStack {
                        Spacer()
                        Text(L10n.string("profile.avatar_crop_hint"))
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.bottom, AppSpacing.section)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { side = containerSide }
                .onChange(of: containerSide) { _, newValue in side = newValue }
            }
            .navigationTitle(L10n.string("profile.avatar_crop_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.done")) { confirm() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - 手势

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(width: lastOffset.width + value.translation.width,
                                      height: lastOffset.height + value.translation.height)
                offset = clamped(proposed, side: side, zoom: zoom)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func magnificationGesture(side: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposedZoom = min(max(lastZoom * value, minZoom), maxZoom)
                zoom = proposedZoom
                offset = clamped(offset, side: side, zoom: proposedZoom)
            }
            .onEnded { _ in
                lastZoom = zoom
                lastOffset = offset
            }
    }

    // MARK: - 几何计算

    /// 让图片铺满裁剪框所需的基础缩放
    private func baseScale(for side: CGFloat) -> CGFloat {
        guard side > 0, image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(side / image.size.width, side / image.size.height)
    }

    /// 限制平移范围，避免裁剪框里露出空白
    private func clamped(_ candidate: CGSize, side: CGFloat, zoom: CGFloat) -> CGSize {
        let base = baseScale(for: side)
        let displayedWidth = image.size.width * base * zoom
        let displayedHeight = image.size.height * base * zoom
        let maxX = max(0, (displayedWidth - side) / 2)
        let maxY = max(0, (displayedHeight - side) / 2)
        return CGSize(width: min(max(candidate.width, -maxX), maxX),
                      height: min(max(candidate.height, -maxY), maxY))
    }

    // MARK: - 输出

    private func confirm() {
        guard side > 0 else {
            onCancel()
            return
        }

        let base = baseScale(for: side)
        let outputScale = outputSide / side
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide), format: format)
        let rendered = renderer.image { _ in
            let drawSize = CGSize(width: image.size.width * base * zoom * outputScale,
                                  height: image.size.height * base * zoom * outputScale)
            let origin = CGPoint(x: (outputSide - drawSize.width) / 2 + offset.width * outputScale,
                                 y: (outputSide - drawSize.height) / 2 + offset.height * outputScale)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }

        onConfirm(rendered)
    }
}

#Preview {
    AvatarCropView(image: UIImage(systemName: "person.crop.square")!, onCancel: {}, onConfirm: { _ in })
}
