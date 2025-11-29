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
    ///   - targetSize: 목표 크기
    /// - Returns: 리사이징 정보가 담긴 AVVideoComposition
    static func createResizeVideoComposition(
        for asset: AVAsset,
        targetSize: CGSize
    ) async -> AVVideoComposition? {
        // 비디오 트랙 가져오기
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let naturalSize = try? await videoTrack.load(.naturalSize)
        let preferredTransform = try? await videoTrack.load(.preferredTransform)
        let frameDuration = try? await videoTrack.load(.minFrameDuration)

        guard let naturalSize, let preferredTransform else {
            return nil
        }

        // AVMutableVideoComposition 생성
        let composition = AVMutableVideoComposition()
        if let frameDuration {
            composition.frameDuration = frameDuration
        }

        // Instruction 생성
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(
            start: .zero,
            duration: (try? await asset.load(.duration)) ?? .zero
        )

        // preferredTransform을 적용한 실제 비디오 크기
        let isRotated90Degrees = preferredTransform.b != 0 || preferredTransform.c != 0
        let videoSize = isRotated90Degrees
            ? CGSize(width: naturalSize.height, height: naturalSize.width)
            : naturalSize
        
        // aspect-fit 스케일 계산
        let scaleX = targetSize.width / videoSize.width
        let scaleY = targetSize.height / videoSize.height
        let scale = min(scaleX, scaleY)

        // 스케일과 회전을 결합한 transform 생성
        let scaleAndRotateTransform: CGAffineTransform
        if isRotated90Degrees {
            // 90도 회전: (x, y) → (scale * x, scale * y) → (scaledHeight - scale * y, scale * x)
            let scaledHeight = naturalSize.height * scale
            scaleAndRotateTransform = CGAffineTransform(
                a: 0,
                b: scale,
                c: -scale,
                d: 0,
                tx: scaledHeight,
                ty: 0
            )
        } else {
            // 회전 없음: 단순 스케일
            scaleAndRotateTransform = CGAffineTransform(scaleX: scale, y: scale)
        }

        // 중앙 정렬 계산
        let scaledWidth = videoSize.width * scale
        let scaledHeight = videoSize.height * scale
        let tx = (targetSize.width - scaledWidth) / 2
        let ty = (targetSize.height - scaledHeight) / 2

        let translateTransform = CGAffineTransform(translationX: tx, y: ty)
        let finalTransform = scaleAndRotateTransform.concatenating(translateTransform)

        // LayerInstruction 적용
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]

        composition.instructions = [instruction]
        composition.renderSize = targetSize

        return composition
    }
}

