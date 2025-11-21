//
//  CompressHelper.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/11/25.
//

import UIKit
import CoreGraphics
import AVFoundation

enum CompressHelper {
    
    static func compressImage(_ imageData: Data, maxSizeInBytes: Int, maxWidth: CGFloat, maxHeight: CGFloat) async -> Data? {
        // 이미지 리사이징
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        
        var resizedImage = image
        
        if image.size.width > maxWidth || image.size.height > maxHeight {
            let ratio = min(maxWidth / image.size.width, maxHeight / image.size.height)
            let newSize = CGSize(
                width: image.size.width * ratio,
                height: image.size.height * ratio
            )

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let scaledImage = UIGraphicsGetImageFromCurrentImageContext() {
                resizedImage = scaledImage
            }
            UIGraphicsEndImageContext()
        }
        
        // 압축 품질 조정
        var compression: CGFloat = 0.8
        let minCompression: CGFloat = 0.1
        let step: CGFloat = 0.1

        guard var imageData = resizedImage.jpegData(compressionQuality: compression) else {
            return nil
        }

        // 이미 maxSize 이하면 그대로 반환
        if imageData.count <= maxSizeInBytes {
            return imageData
        }
        
        // 압축 품질을 점진적으로 낮추면서 maxSize 이하로 만들기
        while imageData.count > maxSizeInBytes && compression > minCompression {
            compression -= step
            if let compressedData = resizedImage.jpegData(compressionQuality: max(compression, minCompression)) {
                imageData = compressedData
            } else {
                break
            }
        }

        return imageData
    }
    
    /// 원본 픽셀 크기를 받아, 가로 880px 기준으로 비율 유지하여 리사이즈된 사이즈를 반환
    static func resizedSizeForiPhoneMax(originalWidth: CGFloat, originalHeight: CGFloat) -> CGSize {
        let maxWidthPx: CGFloat = 880

        // 원본이 이미 더 작으면 리사이즈할 필요 없음
        guard originalWidth > maxWidthPx else {
            return CGSize(width: originalWidth, height: originalHeight)
        }

        let scale = maxWidthPx / originalWidth
        let targetWidth = maxWidthPx
        let targetHeight = originalHeight * scale

        return CGSize(width: targetWidth, height: targetHeight)
    }

    /// 비디오를 리사이징하기 위한 AVVideoComposition 생성
    /// - Parameters:
    ///   - asset: 원본 비디오 asset
    ///   - targetSize: 목표 크기 (nil이면 resizedSizeForiPhoneMax로 자동 계산)
    /// - Returns: 리사이징 정보가 담긴 AVVideoComposition, 리사이즈 불필요시 nil
    static func createResizeVideoComposition(
        for asset: AVAsset,
        targetSize: CGSize? = nil
    ) async -> AVVideoComposition? {
        // 비디오 트랙 가져오기
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let naturalSize = try? await videoTrack.load(.naturalSize)
        let preferredTransform = try? await videoTrack.load(.preferredTransform)
        let frameDuration = try? await videoTrack.load(.minFrameDuration)

        guard let naturalSize = naturalSize else {
            return nil
        }

        // 목표 크기 계산
        let finalTargetSize = targetSize ?? resizedSizeForiPhoneMax(
            originalWidth: naturalSize.width,
            originalHeight: naturalSize.height
        )

        // 이미 목표 크기와 같거나 작으면 리사이즈 불필요
        if finalTargetSize == naturalSize {
            return nil
        }

        // AVMutableVideoComposition 생성
        let composition = AVMutableVideoComposition()
        if let frameDuration = frameDuration {
            composition.frameDuration = frameDuration
        }

        // Instruction 생성
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(
            start: .zero,
            duration: (try? await asset.load(.duration)) ?? .zero
        )

        // LayerInstruction에 스케일 transform 적용
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        // 원본 preferredTransform 적용하여 화면 기준 정렬
        let correctedTransform = preferredTransform ?? .identity

        // 회전 보정 후 프레임 기준 변경되는 경우 보정
        let videoAngleInDegree = atan2(correctedTransform.b, correctedTransform.a) * 180 / .pi
        var renderSize = finalTargetSize

        switch Int(videoAngleInDegree) {
        case 90, -270:
            // 세로 영상의 경우 width/height 뒤집기
            renderSize = CGSize(width: finalTargetSize.height, height: finalTargetSize.width)
        case 180, -180:
            break
        default:
            break
        }

        // 비율을 유지하는 스케일 계산 (aspect fit)
        let scaleX = renderSize.width / naturalSize.width
        let scaleY = renderSize.height / naturalSize.height
        let scale = min(scaleX, scaleY)  // 작은 값 사용하여 비율 유지
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)

        // 최종 변환 = 스케일 → 회전 보정
        let finalTransform = scaleTransform.concatenating(correctedTransform)

        // 중앙 정렬을 위한 이동 계산
        let scaledWidth = naturalSize.width * scale
        let scaledHeight = naturalSize.height * scale
        let tx: CGFloat
        let ty: CGFloat

        switch Int(videoAngleInDegree) {
        case 90:
            tx = (renderSize.width - scaledHeight) / 2 + scaledHeight
            ty = (renderSize.height - scaledWidth) / 2
        case -90, 270:
            tx = (renderSize.width - scaledHeight) / 2
            ty = (renderSize.height - scaledWidth) / 2 + scaledWidth
        case 180, -180:
            tx = (renderSize.width - scaledWidth) / 2 + scaledWidth
            ty = (renderSize.height - scaledHeight) / 2 + scaledHeight
        default:
            tx = (renderSize.width - scaledWidth) / 2
            ty = (renderSize.height - scaledHeight) / 2
        }

        let translateTransform = CGAffineTransform(translationX: tx, y: ty)
        let finalTransformWithTranslation = finalTransform.concatenating(translateTransform)

        layerInstruction.setTransform(finalTransformWithTranslation, at: .zero)
        instruction.layerInstructions = [layerInstruction]

        composition.instructions = [instruction]
        composition.renderSize = renderSize

        return composition
    }
}

