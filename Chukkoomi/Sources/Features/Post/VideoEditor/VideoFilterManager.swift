//
//  VideoFilterManager.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import UIKit
import AVFoundation
@preconcurrency import CoreImage
import Vision
import CoreML
import Metal

/// 비디오 필터 타입
enum VideoFilter: String, CaseIterable, Equatable {
    case blackAndWhite = "흑백"
    case warm = "따뜻한"
    case cool = "차갑게"
    case animeGANHayao = "그림"
    
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
    ///   - targetSize: 목표 크기 (nil이면 원본 크기 사용)
    /// - Returns: 필터가 적용된 AVVideoComposition (필터가 없으면 nil)
    static func createVideoComposition(
        for asset: AVAsset,
        filter: VideoFilter?,
        targetSize: CGSize? = nil,
        isPortraitFromPHAsset: Bool
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
        
        guard let naturalSize = naturalSize else {
            return nil
        }
        
        // 디버깅 로그
        print("🎬 [VideoFilterManager] ====== 필터 적용 시작 ======")
        print("🎬 [VideoFilterManager] 원본 naturalSize: \(naturalSize)")
        print("🎬 [VideoFilterManager] isPortraitFromPHAsset: \(isPortraitFromPHAsset)")
        print("🎬 [VideoFilterManager] targetSize 파라미터: \(targetSize ?? .zero)")
        
        // naturalSize가 가로 방향인지 확인
        let isNaturalSizePortrait = naturalSize.width < naturalSize.height
        print("🎬 [VideoFilterManager] isNaturalSizePortrait: \(isNaturalSizePortrait)")
        
        // 세로 영상인데 naturalSize가 가로로 나온 경우 swap
        let adjustedNaturalSize: CGSize
        if isPortraitFromPHAsset && !isNaturalSizePortrait {
            adjustedNaturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            print("🎬 [VideoFilterManager] naturalSize swap: \(adjustedNaturalSize)")
        } else {
            adjustedNaturalSize = naturalSize
            print("🎬 [VideoFilterManager] naturalSize 유지: \(adjustedNaturalSize)")
        }
        
        // renderSize 계산
        let renderSize = targetSize ?? adjustedNaturalSize
        print("🎬 [VideoFilterManager] renderSize: \(renderSize)")

        // renderSize 방향 확인
        let isRenderSizePortrait = renderSize.width < renderSize.height
        print("🎬 [VideoFilterManager] isRenderSizePortrait: \(isRenderSizePortrait)")

        // renderSize와 naturalSize의 방향이 다르면 90도 회전 필요
        let needsRotation = isRenderSizePortrait != isNaturalSizePortrait
        let correctedTransform: CGAffineTransform
        if needsRotation {
            correctedTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
            print("🎬 [VideoFilterManager] ✅ 90도 회전 transform 적용 (renderSize와 naturalSize 방향 불일치)")
        } else {
            correctedTransform = preferredTransform ?? .identity
            print("🎬 [VideoFilterManager] 원본 transform 사용 (방향 일치)")
        }
        print("🎬 [VideoFilterManager] ====== 필터 적용 종료 ======")


        // aspect-fit 스케일 계산 (회전 전 naturalSize 기준)
        let scaleX = renderSize.width / (needsRotation ? naturalSize.height : naturalSize.width)
        let scaleY = renderSize.height / (needsRotation ? naturalSize.width : naturalSize.height)
        let scale = min(scaleX, scaleY)
        print("🎬 [VideoFilterManager] scale: \(scale) (scaleX: \(scaleX), scaleY: \(scaleY))")
        
        // 중앙 정렬을 위한 offset 계산 (원본 naturalSize 기준)
        let scaledWidth = naturalSize.width * scale
        let scaledHeight = naturalSize.height * scale
        print("🎬 [VideoFilterManager] scaledWidth: \(scaledWidth), scaledHeight: \(scaledHeight)")

        let offsetX: CGFloat
        let offsetY: CGFloat

        if needsRotation {
            // 회전하는 경우: 90도 회전 후 중앙 정렬
            offsetX = (renderSize.width - scaledHeight) / 2
            offsetY = (renderSize.height - scaledWidth) / 2
        } else {
            // 회전 불필요: 일반 중앙 정렬
            offsetX = (renderSize.width - scaledWidth) / 2
            offsetY = (renderSize.height - scaledHeight) / 2
        }
        print("🎬 [VideoFilterManager] offset: (\(offsetX), \(offsetY))")
        
        // AVVideoComposition 생성 (필터 + 리사이즈를 CIImage로 처리)
        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                var outputImage = request.sourceImage

                print("🎨 [VideoFilterManager CIFilter] ====== 프레임 처리 시작 ======")
                print("🎨 [VideoFilterManager CIFilter] 원본 extent: \(outputImage.extent)")
                print("🎨 [VideoFilterManager CIFilter] renderSize: \(renderSize)")

                // 실제 extent 기준으로 방향 확인 (CIImage는 이미 회전된 extent를 가짐)
                let sourceExtent = outputImage.extent
                let isSourcePortrait = sourceExtent.width < sourceExtent.height
                let isRenderPortrait = renderSize.width < renderSize.height
                let actualNeedsRotation = isSourcePortrait != isRenderPortrait

                print("🎨 [VideoFilterManager CIFilter] isSourcePortrait: \(isSourcePortrait)")
                print("🎨 [VideoFilterManager CIFilter] isRenderPortrait: \(isRenderPortrait)")
                print("🎨 [VideoFilterManager CIFilter] actualNeedsRotation: \(actualNeedsRotation)")

                // 1. 필터 적용
                outputImage = applyFilter(filter, to: outputImage, originalImage: outputImage, targetSize: nil)

                // 2. 리사이징 및 회전 (extent 기준으로 판단)
                let actualScale: CGFloat
                let actualTransform: CGAffineTransform

                if actualNeedsRotation {
                    // 회전 필요: extent 기준으로 scale 계산
                    let scaleX = renderSize.width / sourceExtent.height
                    let scaleY = renderSize.height / sourceExtent.width
                    actualScale = min(scaleX, scaleY)
                    actualTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
                    print("🎨 [VideoFilterManager CIFilter] 회전 O - scale: \(actualScale)")
                } else {
                    // 회전 불필요
                    let scaleX = renderSize.width / sourceExtent.width
                    let scaleY = renderSize.height / sourceExtent.height
                    actualScale = min(scaleX, scaleY)
                    actualTransform = .identity
                    print("🎨 [VideoFilterManager CIFilter] 회전 X - scale: \(actualScale)")
                }

                let scaleTransform = CGAffineTransform(scaleX: actualScale, y: actualScale)
                let transformWithRotation = scaleTransform.concatenating(actualTransform)

                outputImage = outputImage.transformed(by: transformWithRotation)

                // 3. transform 후 extent 정규화 (음수 좌표를 원점으로)
                let transformedExtent = outputImage.extent
                print("🎨 [VideoFilterManager CIFilter] transformedExtent: \(transformedExtent)")

                if transformedExtent.origin.x != 0 || transformedExtent.origin.y != 0 {
                    let normalizeTransform = CGAffineTransform(
                        translationX: -transformedExtent.origin.x,
                        y: -transformedExtent.origin.y
                    )
                    outputImage = outputImage.transformed(by: normalizeTransform)
                    print("🎨 [VideoFilterManager CIFilter] normalized extent: \(outputImage.extent)")
                }

                // 4. 중앙 정렬을 위한 offset 계산 (extent 기준)
                let currentExtent = outputImage.extent
                let scaledWidth = sourceExtent.width * actualScale
                let scaledHeight = sourceExtent.height * actualScale

                let actualOffsetX: CGFloat
                let actualOffsetY: CGFloat

                if actualNeedsRotation {
                    // 회전하는 경우: 90도 회전 후 중앙 정렬
                    actualOffsetX = (renderSize.width - scaledHeight) / 2
                    actualOffsetY = (renderSize.height - scaledWidth) / 2
                } else {
                    // 회전 불필요: 일반 중앙 정렬
                    actualOffsetX = (renderSize.width - scaledWidth) / 2
                    actualOffsetY = (renderSize.height - scaledHeight) / 2
                }

                print("🎨 [VideoFilterManager CIFilter] actualOffsetX: \(actualOffsetX), actualOffsetY: \(actualOffsetY)")

                let translateTransform = CGAffineTransform(translationX: actualOffsetX, y: actualOffsetY)
                outputImage = outputImage.transformed(by: translateTransform)
                print("🎨 [VideoFilterManager CIFilter] after translate extent: \(outputImage.extent)")

                // 5. 검정 배경 생성 (빈 공간을 채우기 위해)
                let background = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: renderSize))

                // 6. 이미지를 배경 위에 합성 (outputImage의 extent origin에 따라 위치 결정)
                let composited = outputImage.composited(over: background)
                print("🎨 [VideoFilterManager CIFilter] composited extent: \(composited.extent)")

                // 7. renderSize 영역으로 crop
                let finalOutput = composited.cropped(to: CGRect(origin: .zero, size: renderSize))
                print("🎨 [VideoFilterManager CIFilter] final extent: \(finalOutput.extent)")
                print("🎨 [VideoFilterManager CIFilter] ====== 프레임 처리 완료 ======")
                
                // GPU 가속 컨텍스트를 명시적으로 전달
                request.finish(with: finalOutput, context: VideoFilterHelper.gpuContext)
            }
        )
        
        composition.renderSize = renderSize
        
        return composition
    }
    
    // MARK: - Private Helper Methods
    
    /// CIImage에 필터 적용 (VideoFilterHelper 사용)
    private static func applyFilter(_ filter: VideoFilter, to image: CIImage, originalImage: CIImage, targetSize: CGSize? = nil) -> CIImage {
        return VideoFilterHelper.applyFilter(filter, to: image, originalImage: originalImage, targetSize: targetSize)
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
