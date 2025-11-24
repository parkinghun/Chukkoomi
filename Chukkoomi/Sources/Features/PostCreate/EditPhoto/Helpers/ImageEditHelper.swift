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
    static func compositeImageWithOverlays(
        baseImage: UIImage,
        textOverlays: [EditPhotoFeature.TextOverlay],
        stickers: [EditPhotoFeature.StickerOverlay],
        drawing: PKDrawing,
        canvasSize: CGSize
    ) async -> UIImage {
        await withCheckedContinuation { continuation in
            let size = baseImage.size
            let renderer = UIGraphicsImageRenderer(size: size)

            // 캔버스 크기와 이미지 크기의 스케일 비율 계산
            let scaleX = canvasSize.width > 0 ? size.width / canvasSize.width : 1.0
            let scaleY = canvasSize.height > 0 ? size.height / canvasSize.height : 1.0
            let scale = min(scaleX, scaleY)  // 비율 유지

            let composited = renderer.image { context in
                // 1. 베이스 이미지 그리기
                baseImage.draw(in: CGRect(origin: .zero, size: size))

                // 2. PencilKit drawing 그리기
                if !drawing.strokes.isEmpty {
                    // canvasSize가 설정되어 있으면 사용, 아니면 이미지 크기 사용
                    let effectiveCanvasSize = canvasSize.width > 0 && canvasSize.height > 0
                        ? canvasSize
                        : size
                    let canvasBounds = CGRect(origin: .zero, size: effectiveCanvasSize)
                    // 실제 이미지 크기에 맞는 scale 사용
                    let drawingScale = canvasSize.width > 0 ? size.width / canvasSize.width : 1.0
                    let drawingImage = drawing.image(from: canvasBounds, scale: drawingScale)
                    drawingImage.draw(in: CGRect(origin: .zero, size: size))
                }

                // 3. 스티커 그리기
                for sticker in stickers {
                    guard let stickerImage = UIImage(named: sticker.imageName) else {
                        print("⚠️ Failed to load sticker image: \(sticker.imageName)")
                        continue
                    }

                    let x = sticker.position.x * size.width
                    let y = sticker.position.y * size.height

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

                // 4. 텍스트 오버레이 그리기
                for textOverlay in textOverlays where !textOverlay.text.isEmpty {
                    let x = textOverlay.position.x * size.width
                    let y = textOverlay.position.y * size.height

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
    static func compositeImageWithDrawing(
        baseImage: UIImage,
        drawing: PKDrawing,
        canvasSize: CGSize
    ) async -> UIImage {
        await withCheckedContinuation { continuation in
            let size = baseImage.size
            let renderer = UIGraphicsImageRenderer(size: size)

            let composited = renderer.image { context in
                // 1. 베이스 이미지 그리기
                baseImage.draw(in: CGRect(origin: .zero, size: size))

                // 2. PencilKit drawing 그리기
                // canvasSize는 캔버스 뷰의 포인트 크기, drawing은 이 좌표계를 사용
                // 캔버스 크기 기준으로 drawing 이미지를 생성하고, 이를 이미지 크기에 맞게 그림
                if !drawing.strokes.isEmpty {
                    // canvasSize가 설정되어 있으면 사용, 아니면 이미지 크기 사용
                    let effectiveCanvasSize = canvasSize.width > 0 && canvasSize.height > 0
                        ? canvasSize
                        : size
                    let canvasBounds = CGRect(origin: .zero, size: effectiveCanvasSize)
                    // 실제 이미지 크기에 맞는 scale 사용
                    let drawingScale = canvasSize.width > 0 ? size.width / canvasSize.width : 1.0
                    let drawingImage = drawing.image(from: canvasBounds, scale: drawingScale)
                    // 캔버스 비율로 생성된 이미지를 전체 이미지 크기에 맞춰 그림
                    drawingImage.draw(in: CGRect(origin: .zero, size: size))
                }
            }

            continuation.resume(returning: composited)
        }
    }
}
