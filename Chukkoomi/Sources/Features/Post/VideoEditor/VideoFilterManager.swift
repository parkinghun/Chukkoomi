//
//  VideoFilterManager.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import UIKit
import AVFoundation
@preconcurrency import CoreImage

/// 비디오 필터 타입
enum VideoFilter: String, CaseIterable, Equatable {
    case blackAndWhite = "흑백"
    case warm = "따뜻한"
    case cool = "차갑게"
    case bright = "밝게"

    var displayName: String {
        return rawValue
    }
}

/// 비디오 필터 관리자
struct VideoFilterManager {

    /// 비디오에 필터를 적용한 AVVideoComposition 생성
    /// - Parameters:
    ///   - asset: 원본 비디오 AVAsset
    ///   - filter: 적용할 필터
    /// - Returns: 필터가 적용된 AVVideoComposition (필터가 없으면 nil)
    static func createVideoComposition(
        for asset: AVAsset,
        filter: VideoFilter?
    ) async -> AVVideoComposition? {
        // 필터가 없으면 nil 반환
        guard let filter = filter else {
            return nil
        }

        // 비디오 트랙 가져오기
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let naturalSize = try? await videoTrack.load(.naturalSize)
        let preferredTransform = try? await videoTrack.load(.preferredTransform)

        // AVVideoComposition 생성
        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                let source = request.sourceImage.clampedToExtent()

                // 필터별로 CIFilter 생성 및 적용
                let output = applyFilter(filter, to: source)
                request.finish(with: output, context: nil)
            }
        )

        // naturalSize 설정
        if let naturalSize = naturalSize {
            composition.renderSize = naturalSize
        }

        // Transform 처리 (회전, 플립 등)
        if let preferredTransform = preferredTransform {
            let videoInfo = orientation(from: preferredTransform)
            var isPortrait = false
            switch videoInfo.orientation {
            case .up, .upMirrored, .down, .downMirrored:
                isPortrait = false
            case .left, .leftMirrored, .right, .rightMirrored:
                isPortrait = true
            @unknown default:
                isPortrait = false
            }

            if isPortrait, let naturalSize = naturalSize {
                composition.renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            }
        }

        return composition
    }

    // MARK: - Private Helper Methods

    /// CIImage에 필터 적용
    /// - Parameters:
    ///   - filter: 적용할 필터
    ///   - image: 원본 이미지
    /// - Returns: 필터가 적용된 이미지
    private static func applyFilter(_ filter: VideoFilter, to image: CIImage) -> CIImage {
        switch filter {
        case .blackAndWhite:
            return applyBlackAndWhiteFilter(to: image)
        case .warm:
            return applyWarmFilter(to: image)
        case .cool:
            return image // TODO: 추후 구현
        case .bright:
            return image // TODO: 추후 구현
        }
    }

    /// 흑백 필터 적용
    private static func applyBlackAndWhiteFilter(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIPhotoEffectMono") else {
            return image
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }

    /// 따뜻한 필터 적용
    private static func applyWarmFilter(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else {
            return image
        }

        // 색온도를 높여서 따뜻한 느낌 (오렌지/노란 톤)
        // neutral: (6500, 0) - 일반적인 색온도
        // warm: (8000, 0) - 따뜻한 색온도
        let warmVector = CIVector(x: 8000, y: 0)
        let neutralVector = CIVector(x: 6500, y: 0)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(warmVector, forKey: "inputNeutral")
        filter.setValue(neutralVector, forKey: "inputTargetNeutral")

        return filter.outputImage ?? image
    }

    /// 비디오 orientation 확인 헬퍼
    private static func orientation(from transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false

        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .down
        }

        return (assetOrientation, isPortrait)
    }
}
