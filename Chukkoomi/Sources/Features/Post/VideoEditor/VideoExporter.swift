//
//  VideoExporter.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import UIKit
import Photos
import AVFoundation
import CoreText

/// 비디오 편집을 적용하고 최종 영상을 내보냄
struct VideoExporter {

    enum ExportError: Error, LocalizedError {
        case failedToLoadAsset
        case failedToCreateExportSession
        case exportFailed(Error?)
        case exportCancelled
        case unknownExportStatus

        var errorDescription: String? {
            switch self {
            case .failedToLoadAsset:
                return "비디오를 불러오는데 실패했습니다."
            case .failedToCreateExportSession:
                return "내보내기 세션을 생성하는데 실패했습니다."
            case .exportFailed(let error):
                return "내보내기 실패: \(error?.localizedDescription ?? "알 수 없는 오류")"
            case .exportCancelled:
                return "내보내기가 취소되었습니다."
            case .unknownExportStatus:
                return "알 수 없는 내보내기 상태입니다."
            }
        }
    }

    func export(
        asset: PHAsset,
        editState: EditVideoFeature.EditState,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        let avAsset = try await loadAVAsset(from: asset)
        let (composition, videoComposition) = try await applyEdits(to: avAsset, editState: editState)
        let exportedURL = try await exportComposition(
            composition,
            videoComposition: videoComposition,
            progressHandler: progressHandler
        )
        return exportedURL
    }

    // MARK: - Private Methods

    private func loadAVAsset(from asset: PHAsset) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let avAsset = avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    continuation.resume(throwing: ExportError.failedToLoadAsset)
                }
            }
        }
    }

    private func applyEdits(
        to asset: AVAsset,
        editState: EditVideoFeature.EditState
    ) async throws -> (AVAsset, AVVideoComposition?) {
        let composition = AVMutableComposition()

        // 1) Trim
        let trimmedAsset = try await applyTrim(to: asset, editState: editState, composition: composition)

        // 2) Filter
        var videoComposition = try await applyFilter(to: trimmedAsset, filterType: editState.selectedFilter)

        // 3) Subtitles
        if !editState.subtitles.isEmpty {
//            videoComposition = try await applySubtitles(
//                to: trimmedAsset,
//                editState: editState,
//                baseVideoComposition: videoComposition
//            )
        }

        return (trimmedAsset, videoComposition)
    }

    private func applyTrim(
        to asset: AVAsset,
        editState: EditVideoFeature.EditState,
        composition: AVMutableComposition
    ) async throws -> AVAsset {
        let startTime = CMTime(seconds: editState.trimStartTime, preferredTimescale: 600)

        let assetDuration = try await asset.load(.duration)
        let actualEndTime: CMTime
        if editState.trimEndTime.isInfinite || editState.trimEndTime > assetDuration.seconds {
            actualEndTime = assetDuration
        } else {
            actualEndTime = CMTime(seconds: editState.trimEndTime, preferredTimescale: 600)
        }

        let timeRange = CMTimeRange(start: startTime, end: actualEndTime)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            return composition
        }

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return composition
        }

        try compositionVideoTrack.insertTimeRange(
            timeRange,
            of: videoTrack,
            at: .zero
        )

        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            if let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                try? compositionAudioTrack.insertTimeRange(
                    timeRange,
                    of: audioTrack,
                    at: .zero
                )
            }
        }

        return composition
    }

    private func applyFilter(
        to asset: AVAsset,
        filterType: VideoFilter?
    ) async throws -> AVVideoComposition? {
        return await VideoFilterManager.createVideoComposition(
            for: asset,
            filter: filterType
        )
    }

//    @MainActor
//    private func applySubtitles(
//        to asset: AVAsset,
//        editState: EditVideoFeature.EditState,
//        baseVideoComposition: AVVideoComposition?
//    ) async throws -> AVVideoComposition {
//        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
//            return baseVideoComposition ?? AVMutableVideoComposition()
//        }
//
//        let totalDuration = try await asset.load(.duration).seconds
//
//        let naturalSize = try await videoTrack.load(.naturalSize)
//        let preferredTransform = try await videoTrack.load(.preferredTransform)
//
//        // 회전 고려한 크기
//        let computedSize: CGSize = (preferredTransform.a == 0 && preferredTransform.d == 0)
//            ? CGSize(width: naturalSize.height, height: naturalSize.width)
//            : naturalSize
//
//        // 사용할 renderSize
//        var targetRenderSize = baseVideoComposition?.renderSize ?? computedSize
//
//        func isValidSize(_ s: CGSize) -> Bool {
//            s.width.isFinite && s.height.isFinite && s.width > 0 && s.height > 0
//        }
//        if !isValidSize(targetRenderSize) {
//            if isValidSize(naturalSize) {
//                targetRenderSize = naturalSize
//            } else {
//                let isPortraitGuess = computedSize.height > computedSize.width
//                targetRenderSize = isPortraitGuess ? CGSize(width: 1080, height: 1920)
//                                                   : CGSize(width: 1920, height: 1080)
//            }
//        }
//
//        // videoComposition 준비
//        let mutableVideoComposition: AVMutableVideoComposition
//        if let base = baseVideoComposition?.mutableCopy() as? AVMutableVideoComposition {
//            mutableVideoComposition = base
//            mutableVideoComposition.renderSize = targetRenderSize
//            if mutableVideoComposition.frameDuration == .invalid {
//                mutableVideoComposition.frameDuration = CMTime(value: 1, timescale: 30)
//            }
//            if mutableVideoComposition.instructions.isEmpty {
//                let instruction = AVMutableVideoCompositionInstruction()
//                instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
//                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
//                layerInstruction.setTransform(preferredTransform, at: .zero)
//                instruction.layerInstructions = [layerInstruction]
//                mutableVideoComposition.instructions = [instruction]
//            }
//        } else {
//            mutableVideoComposition = AVMutableVideoComposition()
//            mutableVideoComposition.renderSize = targetRenderSize
//            mutableVideoComposition.frameDuration = CMTime(value: 1, timescale: 30)
//
//            let instruction = AVMutableVideoCompositionInstruction()
//            instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
//
//            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
//            layerInstruction.setTransform(preferredTransform, at: .zero)
//            instruction.layerInstructions = [layerInstruction]
//            mutableVideoComposition.instructions = [instruction]
//        }
//
//        // 레이어 트리 생성 (동기적으로)
//        CATransaction.begin()
//        CATransaction.setDisableActions(true)
//
//        let parentLayer = CALayer()
//        let videoLayer = CALayer()
//
//        parentLayer.frame = CGRect(origin: .zero, size: targetRenderSize)
//        parentLayer.isGeometryFlipped = true
//        videoLayer.frame = CGRect(origin: .zero, size: targetRenderSize)
//        parentLayer.addSublayer(videoLayer)
//
//        // 자막 레이어 추가
//        for subtitle in editState.subtitles {
//            let textLayer = createSubtitleLayer(
//                subtitle: subtitle,
//                videoSize: targetRenderSize,
//                trimStartTime: editState.trimStartTime,
//                totalDuration: totalDuration
//            )
//            parentLayer.addSublayer(textLayer)
//        }
//
//        // CoreAnimationTool 설정
//        mutableVideoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
//            postProcessingAsVideoLayer: videoLayer,
//            in: parentLayer
//        )
//
//        CATransaction.commit()
//
//        return mutableVideoComposition
//    }
//
//    @MainActor
//    private func createSubtitleLayer(
//        subtitle: EditVideoFeature.Subtitle,
//        videoSize: CGSize,
//        trimStartTime: Double,
//        totalDuration: Double
//    ) -> CALayer {
//        // UIImage로 텍스트 렌더링
//        let font = UIFont.boldSystemFont(ofSize: 50)
//        let attributes: [NSAttributedString.Key: Any] = [
//            .font: font,
//            .foregroundColor: UIColor.white,
//            .strokeColor: UIColor.black,
//            .strokeWidth: -5.0
//        ]
//
//        let attributedString = NSAttributedString(string: subtitle.text, attributes: attributes)
//        let textSize = attributedString.size()
//
//        // 이미지 생성
//        let renderer = UIGraphicsImageRenderer(size: CGSize(width: textSize.width + 20, height: textSize.height + 20))
//        let image = renderer.image { context in
//            attributedString.draw(at: CGPoint(x: 10, y: 10))
//        }
//
//        // 이미지 레이어
//        let imageLayer = CALayer()
//        imageLayer.contents = image.cgImage
//        imageLayer.frame = CGRect(
//            x: (videoSize.width - image.size.width) / 2,
//            y: 20,
//            width: image.size.width,
//            height: image.size.height
//        )
//        imageLayer.contentsGravity = .center
//
//        // 시간 보정
//        let rawStart = subtitle.startTime - trimStartTime
//        let rawEnd = subtitle.endTime - trimStartTime
//        var startTime = max(0, rawStart)
//        var endTime = max(0, rawEnd)
//        if endTime < startTime { swap(&startTime, &endTime) }
//
//        if totalDuration.isFinite && totalDuration > 0 {
//            startTime = min(max(0, startTime), totalDuration)
//            endTime = min(max(0, endTime), totalDuration)
//        }
//
//        let minDuration: Double = 0.001
//        let duration = max(endTime - startTime, minDuration)
//
//        // 애니메이션
//        let animation = CAKeyframeAnimation(keyPath: "opacity")
//        animation.values = [0, 1, 1, 0]
//        animation.keyTimes = [0.0, 0.05, 0.95, 1.0].map { NSNumber(value: $0) }
//        animation.duration = duration
//        animation.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
//        animation.isRemovedOnCompletion = false
//        animation.fillMode = .both
//
//        imageLayer.add(animation, forKey: "subtitleOpacity")
//
//        return imageLayer
//    }

    private func exportComposition(
        _ composition: AVAsset,
        videoComposition: AVVideoComposition?,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.failedToCreateExportSession
        }

        exportSession.shouldOptimizeForNetworkUse = false

        if let videoComposition = videoComposition {
            exportSession.videoComposition = videoComposition
        }

        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw ExportError.failedToCreateExportSession
        }

        let videosCacheDirectory = cachesDirectory.appendingPathComponent("ExportedVideos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: videosCacheDirectory.path) {
            try? FileManager.default.createDirectory(at: videosCacheDirectory, withIntermediateDirectories: true)
        }

        let outputURL = videosCacheDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        nonisolated(unsafe) let session = exportSession
        let progressTask = Task {
            while !Task.isCancelled {
                progressHandler(Double(session.progress))
                if session.progress >= 1.0 { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        await exportSession.export()
        progressTask.cancel()

        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw ExportError.exportFailed(exportSession.error)
        case .cancelled:
            throw ExportError.exportCancelled
        default:
            throw ExportError.unknownExportStatus
        }
    }
}
