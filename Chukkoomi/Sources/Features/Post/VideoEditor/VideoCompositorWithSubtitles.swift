//
//  VideoCompositorWithSubtitles.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/20/25.
//

import AVFoundation
@preconcurrency import CoreImage
import UIKit
import Metal

/// 필터와 자막 정보를 담은 커스텀 Instruction
final class SubtitleVideoCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    var timeRange: CMTimeRange
    var enablePostProcessing: Bool = false
    var containsTweening: Bool = false
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    
    let filter: VideoFilter?
    let subtitles: [EditVideoFeature.Subtitle]
    let trimStartTime: Double
    let layerInstructions: [AVVideoCompositionLayerInstruction]
    
    // 리사이징 정보
    let naturalSize: CGSize
    let renderSize: CGSize
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let correctedTransform: CGAffineTransform
    let isPortraitFromPHAsset: Bool
    
    init(
        timeRange: CMTimeRange,
        filter: VideoFilter?,
        subtitles: [EditVideoFeature.Subtitle],
        trimStartTime: Double,
        sourceTrackIDs: [NSValue],
        layerInstructions: [AVVideoCompositionLayerInstruction],
        naturalSize: CGSize,
        renderSize: CGSize,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat,
        correctedTransform: CGAffineTransform,
        isPortraitFromPHAsset: Bool
    ) {
        self.timeRange = timeRange
        self.filter = filter
        self.subtitles = subtitles
        self.trimStartTime = trimStartTime
        self.requiredSourceTrackIDs = sourceTrackIDs
        self.layerInstructions = layerInstructions
        self.naturalSize = naturalSize
        self.renderSize = renderSize
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.correctedTransform = correctedTransform
        self.isPortraitFromPHAsset = isPortraitFromPHAsset
        super.init()
    }
}

/// 필터와 자막을 프레임별로 처리하는 커스텀 Video Compositor
final class VideoCompositorWithSubtitles: NSObject, AVVideoCompositing {
    
    // MARK: - Properties
    
    private let renderContext: CIContext
    private let renderQueue = DispatchQueue(label: "com.chukkoomi.videocompositor", qos: .userInitiated)
    
    // MARK: - AVVideoCompositing Required Properties
    
    nonisolated var sourcePixelBufferAttributes: [String : any Sendable]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
    }
    
    nonisolated var requiredPixelBufferAttributesForRenderContext: [String : any Sendable] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    // MARK: - Initialization
    
    required override init() {
        // GPU 가속을 위한 Metal 기반 CIContext 생성
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.renderContext = CIContext(mtlDevice: metalDevice, options: [
                .useSoftwareRenderer: false,
                .priorityRequestLow: false
            ])
        } else {
            self.renderContext = CIContext(options: [.useSoftwareRenderer: false])
        }
        
        super.init()
    }
    
    // MARK: - AVVideoCompositing Methods
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // 렌더 컨텍스트 변경 시 처리 (필요시)
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async { [weak self] in
            guard let self = self else {
                asyncVideoCompositionRequest.finish(with: NSError(
                    domain: "VideoCompositor",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Compositor deallocated"]
                ))
                return
            }
            
            // Custom instruction에서 필터와 자막 정보 가져오기
            guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? SubtitleVideoCompositionInstruction else {
                asyncVideoCompositionRequest.finish(with: NSError(
                    domain: "VideoCompositor",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid instruction type"]
                ))
                return
            }
            
            // 소스 프레임 가져오기
            guard let sourcePixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: asyncVideoCompositionRequest.sourceTrackIDs[0].int32Value) else {
                asyncVideoCompositionRequest.finish(with: NSError(
                    domain: "VideoCompositor",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to get source frame"]
                ))
                return
            }
            
            // CIImage로 변환
            var outputImage = CIImage(cvPixelBuffer: sourcePixelBuffer)

            print("🎞️ [VideoCompositor] ====== 프레임 처리 시작 ======")
            print("🎞️ [VideoCompositor] 원본 extent: \(outputImage.extent)")
            print("🎞️ [VideoCompositor] instruction.renderSize: \(instruction.renderSize)")
            print("🎞️ [VideoCompositor] instruction.correctedTransform: \(instruction.correctedTransform)")

            // 1. 필터 적용
            if let filter = instruction.filter {
                outputImage = self.applyFilter(filter, to: outputImage)
            }

            // 2. 원본 비디오의 preferredTransform을 먼저 적용 (raw 픽셀을 실제 방향으로)
            if instruction.correctedTransform != .identity {
                print("🎞️ [VideoCompositor] 원본 preferredTransform 적용 전 extent: \(outputImage.extent)")
                outputImage = outputImage.transformed(by: instruction.correctedTransform)
                print("🎞️ [VideoCompositor] 원본 preferredTransform 적용 후 extent: \(outputImage.extent)")

                // transform 후 extent 정규화
                if outputImage.extent.origin.x != 0 || outputImage.extent.origin.y != 0 {
                    let normalizeTransform = CGAffineTransform(
                        translationX: -outputImage.extent.origin.x,
                        y: -outputImage.extent.origin.y
                    )
                    outputImage = outputImage.transformed(by: normalizeTransform)
                    print("🎞️ [VideoCompositor] preferredTransform 후 normalized extent: \(outputImage.extent)")
                }
            }

            // 3. 실제 extent 기준으로 방향 확인
            let sourceExtent = outputImage.extent
            let isSourcePortrait = sourceExtent.width < sourceExtent.height
            let isRenderPortrait = instruction.renderSize.width < instruction.renderSize.height
            let actualNeedsRotation = isSourcePortrait != isRenderPortrait

            print("🎞️ [VideoCompositor] 실제 sourceExtent (transform 후): \(sourceExtent)")
            print("🎞️ [VideoCompositor] isSourcePortrait: \(isSourcePortrait)")
            print("🎞️ [VideoCompositor] isRenderPortrait: \(isRenderPortrait)")
            print("🎞️ [VideoCompositor] actualNeedsRotation: \(actualNeedsRotation)")

            // 3. 리사이징 및 회전 (extent 기준으로 판단)
            let actualScale: CGFloat
            let actualTransform: CGAffineTransform

            if actualNeedsRotation {
                // 회전 필요: extent 기준으로 scale 계산
                let scaleX = instruction.renderSize.width / sourceExtent.height
                let scaleY = instruction.renderSize.height / sourceExtent.width
                actualScale = min(scaleX, scaleY)
                actualTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
                print("🎞️ [VideoCompositor] 회전 O - scale: \(actualScale)")
            } else {
                // 회전 불필요
                let scaleX = instruction.renderSize.width / sourceExtent.width
                let scaleY = instruction.renderSize.height / sourceExtent.height
                actualScale = min(scaleX, scaleY)
                actualTransform = .identity
                print("🎞️ [VideoCompositor] 회전 X - scale: \(actualScale)")
            }

            let scaleTransform = CGAffineTransform(scaleX: actualScale, y: actualScale)
            print("🎞️ [VideoCompositor] scaleTransform: \(scaleTransform)")
            print("🎞️ [VideoCompositor] actualTransform (회전): \(actualTransform)")

            let transformWithRotation = scaleTransform.concatenating(actualTransform)
            print("🎞️ [VideoCompositor] 최종 transform (scale + rotation): \(transformWithRotation)")
            print("🎞️ [VideoCompositor] transform 적용 전 extent: \(outputImage.extent)")

            outputImage = outputImage.transformed(by: transformWithRotation)
            print("🎞️ [VideoCompositor] transform 적용 후 extent: \(outputImage.extent)")

            // 4. transform 후 extent 정규화 (음수 좌표를 원점으로)
            let transformedExtent = outputImage.extent
            print("🎞️ [VideoCompositor] transformedExtent: \(transformedExtent)")

            if transformedExtent.origin.x != 0 || transformedExtent.origin.y != 0 {
                let normalizeTransform = CGAffineTransform(
                    translationX: -transformedExtent.origin.x,
                    y: -transformedExtent.origin.y
                )
                outputImage = outputImage.transformed(by: normalizeTransform)
                print("🎞️ [VideoCompositor] normalized extent: \(outputImage.extent)")
            }

            // 5. 중앙 정렬을 위한 offset 계산 (extent 기준)
            let scaledWidth = sourceExtent.width * actualScale
            let scaledHeight = sourceExtent.height * actualScale

            let actualOffsetX: CGFloat
            let actualOffsetY: CGFloat

            if actualNeedsRotation {
                // 회전하는 경우: 90도 회전 후 중앙 정렬
                actualOffsetX = (instruction.renderSize.width - scaledHeight) / 2
                actualOffsetY = (instruction.renderSize.height - scaledWidth) / 2
            } else {
                // 회전 불필요: 일반 중앙 정렬
                actualOffsetX = (instruction.renderSize.width - scaledWidth) / 2
                actualOffsetY = (instruction.renderSize.height - scaledHeight) / 2
            }

            print("🎞️ [VideoCompositor] actualOffsetX: \(actualOffsetX), actualOffsetY: \(actualOffsetY)")

            let translateTransform = CGAffineTransform(translationX: actualOffsetX, y: actualOffsetY)
            outputImage = outputImage.transformed(by: translateTransform)
            print("🎞️ [VideoCompositor] after translate extent: \(outputImage.extent)")

            // 5. 검정 배경 생성 (빈 공간을 채우기 위해)
            let background = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: instruction.renderSize))

            // 6. 이미지를 배경 위에 합성 (outputImage의 extent origin에 따라 위치 결정)
            outputImage = outputImage.composited(over: background)
            print("🎞️ [VideoCompositor] composited extent: \(outputImage.extent)")

            // 7. renderSize 영역으로 crop
            outputImage = outputImage.cropped(to: CGRect(origin: .zero, size: instruction.renderSize))
            print("🎞️ [VideoCompositor] cropped extent: \(outputImage.extent)")

            // 8. 자막 적용
            let currentTime = CMTimeGetSeconds(asyncVideoCompositionRequest.compositionTime)
            let adjustedTime = currentTime + instruction.trimStartTime

            if let subtitle = self.findSubtitle(at: adjustedTime, subtitles: instruction.subtitles) {
                if let subtitleImage = self.createSubtitleImage(
                    text: subtitle.text,
                    videoSize: instruction.renderSize
                ) {
                    // 자막 이미지를 비디오 프레임 위에 합성
                    outputImage = subtitleImage.composited(over: outputImage)
                    print("🎞️ [VideoCompositor] 자막 합성 후 extent: \(outputImage.extent)")
                }
            }

            print("🎞️ [VideoCompositor] 최종 extent: \(outputImage.extent)")
            print("🎞️ [VideoCompositor] ====== 프레임 처리 완료 ======")

            // 9. 렌더링 (Core Image Y-up → 비디오 버퍼 Y-down 보정)
            guard let renderPixelBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
                asyncVideoCompositionRequest.finish(with: NSError(
                    domain: "VideoCompositor",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create render pixel buffer"]
                ))
                return
            }

            self.renderContext.render(outputImage, to: renderPixelBuffer)
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: renderPixelBuffer)
        }
    }
    
    func cancelAllPendingVideoCompositionRequests() {
        // 모든 대기 중인 요청 취소
    }
    
    // MARK: - Private Helper Methods
    
    /// 필터 적용 (VideoFilterHelper 사용)
    private func applyFilter(_ filter: VideoFilter, to image: CIImage) -> CIImage {
        // AnimeGAN은 너무 무거워서 실시간 처리 불가 - 커스텀 compositor에서는 스킵
        if filter == .animeGANHayao {
            return image
        }
        return VideoFilterHelper.applyFilter(filter, to: image)
    }
    
    /// 현재 시간에 해당하는 자막 찾기
    private func findSubtitle(at time: Double, subtitles: [EditVideoFeature.Subtitle]) -> EditVideoFeature.Subtitle? {
        return subtitles.first { subtitle in
            time >= subtitle.startTime && time < subtitle.endTime
        }
    }
    
    /// 자막 이미지 생성 (미리보기와 동일한 스타일)
    private func createSubtitleImage(text: String, videoSize: CGSize) -> CIImage? {
        // 매우 높은 해상도로 렌더링하여 리사이징 후에도 선명도 유지
        let renderScale: CGFloat = 4.0
        
        // 자막 크기를 고정 (iPhone Max 세로 기준: 1320px)
        let baseWidth: CGFloat = 1320.0
        let baseFontSize: CGFloat = baseWidth * 0.06  // 약 79pt
        let fontSize = baseFontSize * renderScale
        
        let font = UIFont.boldSystemFont(ofSize: fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        // 흰색 텍스트 속성
        let whiteAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        // 검정 테두리 속성
        let blackAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        let whiteString = NSAttributedString(string: text, attributes: whiteAttributes)
        let blackString = NSAttributedString(string: text, attributes: blackAttributes)
        
        // 텍스트 크기 계산
        let maxWidth = baseWidth * renderScale * 0.9
        let textSize = whiteString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        // 여백 추가 (테두리 offset을 고려하여 더 크게)
        let outlineOffset: CGFloat = 2.0 * renderScale
        let padding: CGFloat = 20.0 * renderScale + outlineOffset
        let imageSize = CGSize(
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )
        
        // UIGraphicsImageRenderer로 고해상도 텍스트 렌더링
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
            
            let textRect = CGRect(
                x: padding,
                y: padding,
                width: textSize.width,
                height: textSize.height
            )
            
            // 미리보기와 동일하게 8방향 검정 테두리 그리기
            for i in 0..<8 {
                let offsetX = CGFloat(i % 3 - 1) * outlineOffset
                let offsetY = CGFloat(i / 3 - 1) * outlineOffset
                
                let outlineRect = textRect.offsetBy(dx: offsetX, dy: offsetY)
                blackString.draw(in: outlineRect)
            }
            
            // 흰색 텍스트 (중앙)
            whiteString.draw(in: textRect)
        }
        
        // UIImage를 CIImage로 변환
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        var textImage = CIImage(cgImage: cgImage)
        
        // 기준 크기로 스케일 다운 (renderScale 배수만큼)
        let scaleDown = CGAffineTransform(scaleX: 1.0 / renderScale, y: 1.0 / renderScale)
        textImage = textImage.transformed(by: scaleDown)
        
        // 실제 비디오 크기에 맞게 자막 크기 조정
        let videoScale = videoSize.width / baseWidth
        let finalScale = CGAffineTransform(scaleX: videoScale, y: videoScale)
        textImage = textImage.transformed(by: finalScale)
        
        // 텍스트를 비디오 중앙 하단에 배치
        // Core Image는 좌하단이 (0,0)
        let textExtent = textImage.extent
        let xPosition = (videoSize.width - textExtent.width) / 2
        let yPosition = videoSize.height * 0.05 // 하단에서 5% 위치 (더 아래로)
        
        textImage = textImage.transformed(by: CGAffineTransform(
            translationX: xPosition,
            y: yPosition
        ))
        
        return textImage
    }
}

