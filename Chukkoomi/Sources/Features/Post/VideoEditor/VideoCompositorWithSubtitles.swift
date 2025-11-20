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

    init(
        timeRange: CMTimeRange,
        filter: VideoFilter?,
        subtitles: [EditVideoFeature.Subtitle],
        trimStartTime: Double,
        sourceTrackIDs: [NSValue],
        layerInstructions: [AVVideoCompositionLayerInstruction]
    ) {
        self.timeRange = timeRange
        self.filter = filter
        self.subtitles = subtitles
        self.trimStartTime = trimStartTime
        self.requiredSourceTrackIDs = sourceTrackIDs
        self.layerInstructions = layerInstructions
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

            // 1. 필터 적용
            if let filter = instruction.filter {
                outputImage = self.applyFilter(filter, to: outputImage)
            }

            // 2. 자막 적용
            let currentTime = CMTimeGetSeconds(asyncVideoCompositionRequest.compositionTime)
            let adjustedTime = currentTime + instruction.trimStartTime

            if let subtitle = self.findSubtitle(at: adjustedTime, subtitles: instruction.subtitles) {
                let videoSize = outputImage.extent.size
                if let subtitleImage = self.createSubtitleImage(
                    text: subtitle.text,
                    videoSize: videoSize
                ) {
                    // 자막 이미지를 비디오 프레임 위에 합성
                    outputImage = subtitleImage.composited(over: outputImage)
                }
            }

            // 3. 렌더링
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

    /// 자막 이미지 생성 (Core Image 사용)
    private func createSubtitleImage(text: String, videoSize: CGSize) -> CIImage? {
        // NSAttributedString으로 텍스트 스타일링
        let fontSize: CGFloat = videoSize.height * 0.06 // 비디오 높이의 6%
        let font = UIFont.boldSystemFont(ofSize: fontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle,
            .strokeColor: UIColor.black,
            .strokeWidth: -3.0
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // CIAttributedTextImageGenerator 필터 사용
        guard let filter = CIFilter(name: "CIAttributedTextImageGenerator") else {
            return nil
        }

        filter.setValue(attributedString, forKey: "inputText")

        guard var textImage = filter.outputImage else {
            return nil
        }

        // 텍스트 이미지의 실제 크기 가져오기
        let textExtent = textImage.extent

        // 텍스트를 비디오 중앙 하단에 배치
        // Core Image는 좌하단이 (0,0)
        let xPosition = (videoSize.width - textExtent.width) / 2
        let yPosition = videoSize.height * 0.1 // 하단에서 10% 위치

        textImage = textImage.transformed(by: CGAffineTransform(
            translationX: xPosition,
            y: yPosition
        ))

        return textImage
    }
}
