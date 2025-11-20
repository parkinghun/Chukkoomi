//
//  VideoExporter.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import Photos
import AVFoundation

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
        preProcessedVideoURL: URL? = nil,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        let avAsset: AVAsset

        // AnimeGAN 필터이고 미리 처리된 영상이 있으면 사용
        if editState.selectedFilter == .animeGANHayao, let preProcessedURL = preProcessedVideoURL {
            avAsset = AVAsset(url: preProcessedURL)
        } else {
            avAsset = try await loadAVAsset(from: asset)
        }

        // 미리 처리된 영상을 사용하는 경우, 필터는 이미 적용되어 있음
        let isFilterAlreadyApplied = editState.selectedFilter == .animeGANHayao && preProcessedVideoURL != nil
        let (composition, videoComposition) = try await applyEdits(
            to: avAsset,
            editState: editState,
            isFilterAlreadyApplied: isFilterAlreadyApplied
        )
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
        editState: EditVideoFeature.EditState,
        isFilterAlreadyApplied: Bool
    ) async throws -> (AVAsset, AVVideoComposition?) {
        let composition = AVMutableComposition()

        // 1) Trim
        let trimmedAsset = try await applyTrim(to: asset, editState: editState, composition: composition)

        // 2) 목표 크기 계산 (Resize)
        guard let videoTrack = try await trimmedAsset.loadTracks(withMediaType: .video).first else {
            return (trimmedAsset, nil)
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)

        // 전처리 영상을 사용하는 경우, 이미 리사이징되어 있으므로 naturalSize를 그대로 사용
        let targetSize: CGSize
        if isFilterAlreadyApplied {
            // 전처리 영상은 이미 리사이징되어 있음
            targetSize = naturalSize
        } else {
            // 새로 처리하는 경우 목표 크기 계산 (회전 고려)
            let baseTargetSize = CompressHelper.resizedSizeForiPhoneMax(
                originalWidth: naturalSize.width,
                originalHeight: naturalSize.height
            )

            // 회전 각도 확인하여 세로 영상이면 width/height swap
            let videoAngleInDegree = atan2(preferredTransform.b, preferredTransform.a) * 180 / .pi

            switch Int(videoAngleInDegree) {
            case 90, -270:
                // 세로 영상: width/height swap
                targetSize = CGSize(width: baseTargetSize.height, height: baseTargetSize.width)
            default:
                targetSize = baseTargetSize
            }
        }

        // 3) Filter와 Subtitles 처리
        let videoComposition: AVVideoComposition?

        if !editState.subtitles.isEmpty {
            // 자막이 있으면: 커스텀 compositor가 필터와 자막을 함께 처리
            // 단, 필터가 이미 적용된 경우 필터는 스킵
            let filterToApply = isFilterAlreadyApplied ? nil : editState.selectedFilter
            videoComposition = try await applySubtitles(
                to: trimmedAsset,
                editState: editState,
                filterToApply: filterToApply,
                targetSize: targetSize
            )
        } else if editState.selectedFilter != nil && !isFilterAlreadyApplied {
            // 자막이 없고 필터만 있으면: VideoFilterManager로 필터만 적용
            // (이미 필터가 적용된 경우는 제외)
            videoComposition = await VideoFilterManager.createVideoComposition(
                for: trimmedAsset,
                filter: editState.selectedFilter,
                targetSize: targetSize
            )
        } else if targetSize != naturalSize {
            // 필터도 자막도 없지만 리사이즈가 필요한 경우
            videoComposition = await CompressHelper.createResizeVideoComposition(
                for: trimmedAsset,
                targetSize: targetSize
            )
        } else {
            // 필터도 자막도 리사이즈도 필요 없으면: nil
            videoComposition = nil
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

    private func applySubtitles(
        to asset: AVAsset,
        editState: EditVideoFeature.EditState,
        filterToApply: VideoFilter?,
        targetSize: CGSize? = nil
    ) async throws -> AVVideoComposition {
        // 비디오 트랙 가져오기
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.failedToLoadAsset
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let frameDuration = try await videoTrack.load(.minFrameDuration)
        let duration = try await asset.load(.duration)

        // 목표 크기 설정 (targetSize가 제공되면 사용, 아니면 naturalSize)
        let renderSize = targetSize ?? naturalSize

        // 커스텀 compositor를 사용하는 AVMutableVideoComposition 생성
        let composition = AVMutableVideoComposition()
        composition.frameDuration = frameDuration
        composition.renderSize = renderSize
        composition.customVideoCompositorClass = VideoCompositorWithSubtitles.self

        // LayerInstruction 생성
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        // 커스텀 Instruction 생성 (필터와 자막 정보 포함)
        // filterToApply를 사용 - 이미 필터가 적용된 경우 nil
        let instruction = SubtitleVideoCompositionInstruction(
            timeRange: CMTimeRange(start: .zero, duration: duration),
            filter: filterToApply,
            subtitles: editState.subtitles,
            trimStartTime: editState.trimStartTime,
            sourceTrackIDs: [NSNumber(value: videoTrack.trackID)],
            layerInstructions: [layerInstruction]
        )

        composition.instructions = [instruction]

        return composition
    }


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
