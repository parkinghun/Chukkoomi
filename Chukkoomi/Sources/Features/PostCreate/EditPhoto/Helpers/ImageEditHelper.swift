//
//  ImageEditHelper.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import UIKit
import SwiftUI
import PencilKit

enum ImageEditHelper {

    // MARK: - Scale Mode
    enum ScaleMode {
        case fill  // scaledToFill
        case fit   // scaledToFit
    }

    // MARK: - Calculate Displayed Image Region
    /// scaledToFill 시 displayImage의 어느 영역이 실제로 화면에 표시되는지 계산
    /// - Parameters:
    ///   - imageSize: displayImage의 실제 크기 (픽셀)
    ///   - containerSize: 화면 컨테이너 크기 (포인트)
    /// - Returns: displayImage 좌표계 기준으로 실제 표시되는 영역
    /// - Note: scaledToFill + clipped 시 이미지의 일부만 보이는데, 그 영역을 반환
    static func calculateDisplayedImageRegion(
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var displayedWidth: CGFloat
        var displayedHeight: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if imageAspect > containerAspect {
            // 이미지가 더 넓음 → 높이를 맞추고 좌우가 잘림
            // 예: 2000×1000 이미지를 1000×800 컨테이너에 표시
            // → 1600×800으로 스케일 → 좌우 200px씩 잘림
            displayedHeight = imageSize.height
            displayedWidth = displayedHeight * containerAspect
            offsetX = (imageSize.width - displayedWidth) / 2
        } else {
            // 이미지가 더 높음 → 너비를 맞추고 상하가 잘림
            displayedWidth = imageSize.width
            displayedHeight = displayedWidth / containerAspect
            offsetY = (imageSize.height - displayedHeight) / 2
        }

        return CGRect(x: offsetX, y: offsetY, width: displayedWidth, height: displayedHeight)
    }

    // MARK: - Calculate Visible Image Frame
    /// scaledToFill 또는 scaledToFit 시 실제 이미지 표시 영역 계산
    /// - Parameters:
    ///   - imageSize: 원본 이미지 크기
    ///   - containerSize: 컨테이너(캔버스) 크기
    ///   - scaleMode: 스케일 모드 (.fill 또는 .fit)
    /// - Returns: 실제 이미지가 표시되는 영역의 CGRect (컨테이너 좌표계 기준)
    static func calculateVisibleImageFrame(
        imageSize: CGSize,
        containerSize: CGSize,
        scaleMode: ScaleMode
    ) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var displayWidth: CGFloat
        var displayHeight: CGFloat

        switch scaleMode {
        case .fill:
            // scaledToFill: 전체를 채우면서 aspect ratio 유지
            if imageAspect > containerAspect {
                // 이미지가 더 넓음 → 높이를 맞추고 좌우가 잘림
                displayHeight = containerSize.height
                displayWidth = displayHeight * imageAspect
            } else {
                // 이미지가 더 높음 → 너비를 맞추고 상하가 잘림
                displayWidth = containerSize.width
                displayHeight = displayWidth / imageAspect
            }
        case .fit:
            // scaledToFit: 전체가 보이도록 aspect ratio 유지
            if imageAspect > containerAspect {
                displayWidth = containerSize.width
                displayHeight = displayWidth / imageAspect
            } else {
                displayHeight = containerSize.height
                displayWidth = displayHeight * imageAspect
            }
        }

        // 중앙 정렬
        let x = (containerSize.width - displayWidth) / 2
        let y = (containerSize.height - displayHeight) / 2

        return CGRect(x: x, y: y, width: displayWidth, height: displayHeight)
    }

    // MARK: - Resize Image
    /// 이미지를 주어진 크기로 리사이즈
    static func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        await withCheckedContinuation { continuation in
            let renderer = UIGraphicsImageRenderer(size: size)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            continuation.resume(returning: resized)
        }
    }

    // MARK: - Calculate Crop Rect
    /// 전체 이미지 크기에서 주어진 비율로 최대 크기의 cropRect 계산
    static func calculateCropRectForAspectRatio(_ aspectRatio: CGFloat) -> CGRect {
        let fullWidth: CGFloat = 1.0
        let fullHeight: CGFloat = 1.0
        let fullAspectRatio = fullWidth / fullHeight  // 1.0

        var width: CGFloat
        var height: CGFloat

        if aspectRatio > fullAspectRatio {
            // 원하는 비율이 더 넓음 -> 너비를 전체로, 높이를 조정
            width = fullWidth
            height = width / aspectRatio
        } else {
            // 원하는 비율이 더 높음 -> 높이를 전체로, 너비를 조정
            height = fullHeight
            width = height * aspectRatio
        }

        // 중앙에 배치
        let x = (fullWidth - width) / 2
        let y = (fullHeight - height) / 2

        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Crop Image
    /// 이미지를 normalized rect (0.0~1.0)로 자르기
    static func cropImage(_ image: UIImage, to normalizedRect: CGRect) async -> UIImage? {
        await withCheckedContinuation { continuation in
            // Normalized rect (0.0~1.0)를 실제 픽셀 좌표로 변환
            let scale = image.scale
            let imageSize = image.size

            let x = normalizedRect.origin.x * imageSize.width * scale
            let y = normalizedRect.origin.y * imageSize.height * scale
            let width = normalizedRect.width * imageSize.width * scale
            let height = normalizedRect.height * imageSize.height * scale

            let cropRect = CGRect(x: x, y: y, width: width, height: height)

            guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
                continuation.resume(returning: nil)
                return
            }

            let croppedImage = UIImage(
                cgImage: cgImage,
                scale: image.scale,
                orientation: image.imageOrientation
            )
            continuation.resume(returning: croppedImage)
        }
    }

    // MARK: - Composite Image with Overlays
    /// 이미지에 텍스트 오버레이, 스티커, 그림을 합성
    /// - Parameters:
    ///   - baseImage: 베이스 이미지
    ///   - textOverlays: 텍스트 오버레이 목록
    ///   - stickers: 스티커 목록
    ///   - drawing: PencilKit drawing
    ///   - canvasSize: DrawingCanvas 크기 (visibleImageFrame 크기)
    ///   - containerSize: 화면 컨테이너 크기
    static func compositeImageWithOverlays(
        baseImage: UIImage,
        textOverlays: [EditPhotoFeature.TextOverlay],
        stickers: [EditPhotoFeature.StickerOverlay],
        drawing: PKDrawing,
        canvasSize: CGSize,
        containerSize: CGSize
    ) async -> UIImage {
        await withCheckedContinuation { continuation in
            let size = baseImage.size
            let renderer = UIGraphicsImageRenderer(size: size)

            // scaledToFill 시 실제 표시되는 이미지 영역 계산
            let displayedRegion = calculateDisplayedImageRegion(
                imageSize: size,
                containerSize: containerSize
            )

            // 캔버스 크기와 실제 표시 영역의 스케일 비율 계산
            let scaleX = canvasSize.width > 0 ? displayedRegion.width / canvasSize.width : 1.0
            let scaleY = canvasSize.height > 0 ? displayedRegion.height / canvasSize.height : 1.0
            let scale = min(scaleX, scaleY)  // 비율 유지

            let composited = renderer.image { context in
                // 1. 베이스 이미지 그리기
                baseImage.draw(in: CGRect(origin: .zero, size: size))

                // 2. PencilKit drawing 그리기
                if !drawing.strokes.isEmpty {
                    let canvasBounds = CGRect(origin: .zero, size: canvasSize)
                    // displayedRegion 크기 기준으로 scale 계산
                    let drawingScale = displayedRegion.width / canvasSize.width
                    let drawingImage = drawing.image(from: canvasBounds, scale: drawingScale)
                    // displayedRegion 위치에 그리기 (오프셋 적용)
                    drawingImage.draw(in: displayedRegion)
                }

                // 3. 스티커 그리기 (displayedRegion 기준으로 좌표 변환)
                for sticker in stickers {
                    guard let stickerImage = UIImage(named: sticker.imageName) else {
                        print("⚠️ Failed to load sticker image: \(sticker.imageName)")
                        continue
                    }

                    // normalized 좌표를 displayedRegion 좌표로 변환
                    let x = displayedRegion.minX + sticker.position.x * displayedRegion.width
                    let y = displayedRegion.minY + sticker.position.y * displayedRegion.height

                    // 스티커 크기 (캔버스 기준 20%를 이미지 크기로 스케일링)
                    let baseCanvasStickerSize = canvasSize.width * 0.2  // 캔버스 기준 크기
                    let baseStickerSize = baseCanvasStickerSize * scale  // 이미지 기준 크기
                    let scaledSize = baseStickerSize * sticker.scale

                    // 스티커 렉트 (중앙 기준)
                    let stickerRect = CGRect(
                        x: x - scaledSize / 2,
                        y: y - scaledSize / 2,
                        width: scaledSize,
                        height: scaledSize
                    )

                    // Transform 적용 (회전)
                    context.cgContext.saveGState()
                    context.cgContext.translateBy(x: x, y: y)
                    context.cgContext.rotate(by: CGFloat(sticker.rotation.radians))
                    context.cgContext.translateBy(x: -x, y: -y)

                    stickerImage.draw(in: stickerRect)

                    context.cgContext.restoreGState()
                }

                // 4. 텍스트 오버레이 그리기 (displayedRegion 기준으로 좌표 변환)
                for textOverlay in textOverlays where !textOverlay.text.isEmpty {
                    // normalized 좌표를 displayedRegion 좌표로 변환
                    let x = displayedRegion.minX + textOverlay.position.x * displayedRegion.width
                    let y = displayedRegion.minY + textOverlay.position.y * displayedRegion.height

                    // 텍스트 크기를 이미지 크기에 맞게 스케일링
                    let scaledFontSize = textOverlay.fontSize * scale

                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: scaledFontSize, weight: .bold),
                        .foregroundColor: UIColor(textOverlay.color)
                    ]

                    let attributedString = NSAttributedString(
                        string: textOverlay.text,
                        attributes: attributes
                    )

                    let textSize = attributedString.size()
                    let textRect = CGRect(
                        x: x - textSize.width / 2,
                        y: y - textSize.height / 2,
                        width: textSize.width,
                        height: textSize.height
                    )

                    attributedString.draw(in: textRect)
                }
            }

            continuation.resume(returning: composited)
        }
    }

    // MARK: - Composite Image with Drawing Only
    /// 이미지에 PencilKit 그림만 합성
    /// - Parameters:
    ///   - baseImage: 베이스 이미지
    ///   - drawing: PencilKit drawing
    ///   - canvasSize: DrawingCanvas 크기 (visibleImageFrame 크기)
    ///   - containerSize: 화면 컨테이너 크기
    static func compositeImageWithDrawing(
        baseImage: UIImage,
        drawing: PKDrawing,
        canvasSize: CGSize,
        containerSize: CGSize
    ) async -> UIImage {
        await withCheckedContinuation { continuation in
            let size = baseImage.size
            let renderer = UIGraphicsImageRenderer(size: size)

            let composited = renderer.image { context in
                // 1. 베이스 이미지 그리기
                baseImage.draw(in: CGRect(origin: .zero, size: size))

                // 2. PencilKit drawing 그리기
                if !drawing.strokes.isEmpty {
                    // scaledToFill 시 실제 표시되는 이미지 영역 계산
                    let displayedRegion = calculateDisplayedImageRegion(
                        imageSize: size,
                        containerSize: containerSize
                    )

                    let canvasBounds = CGRect(origin: .zero, size: canvasSize)
                    // displayedRegion 크기 기준으로 scale 계산
                    let drawingScale = displayedRegion.width / canvasSize.width
                    let drawingImage = drawing.image(from: canvasBounds, scale: drawingScale)

                    // displayedRegion 위치에 그리기 (오프셋 적용)
                    drawingImage.draw(in: displayedRegion)
                }
            }

            continuation.resume(returning: composited)
        }
    }
}
