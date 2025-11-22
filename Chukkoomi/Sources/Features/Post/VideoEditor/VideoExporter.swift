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

        // PHAsset의 실제 픽셀 크기로 세로 영상 판단 (더 정확함)
        let isPortraitFromPHAsset = asset.pixelWidth < asset.pixelHeight
        print("🎥 [VideoExporter.export] PHAsset 정보:")
        print("🎥 [VideoExporter.export] pixelWidth: \(asset.pixelWidth)")
        print("🎥 [VideoExporter.export] pixelHeight: \(asset.pixelHeight)")
        print("🎥 [VideoExporter.export] isPortrait (PHAsset): \(isPortraitFromPHAsset)")

        // 미리 처리된 영상을 사용하는 경우, 필터는 이미 적용되어 있음
        let isFilterAlreadyApplied = editState.selectedFilter == .animeGANHayao && preProcessedVideoURL != nil
        let (composition, videoComposition) = try await applyEdits(
            to: avAsset,
            editState: editState,
            isFilterAlreadyApplied: isFilterAlreadyApplied,
            isPortraitFromPHAsset: isPortraitFromPHAsset
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
        isFilterAlreadyApplied: Bool,
        isPortraitFromPHAsset: Bool
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

        // 디버깅 로그
        print("📤 [VideoExporter.applyEdits] ====== 편집 적용 시작 ======")
        print("📤 [VideoExporter.applyEdits] naturalSize: \(naturalSize)")
        print("📤 [VideoExporter.applyEdits] preferredTransform: \(preferredTransform)")
        print("📤 [VideoExporter.applyEdits] isFilterAlreadyApplied: \(isFilterAlreadyApplied)")
        print("📤 [VideoExporter.applyEdits] isPortraitFromPHAsset: \(isPortraitFromPHAsset)")

        // 세로 영상일 때 naturalSize 조정 (CompressHelper와 동일한 로직)
        let adjustedNaturalSize: CGSize
        if isPortraitFromPHAsset {
            adjustedNaturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            print("📤 [VideoExporter.applyEdits] 세로 영상 - naturalSize swap: \(adjustedNaturalSize)")
        } else {
            adjustedNaturalSize = naturalSize
            print("📤 [VideoExporter.applyEdits] 가로 영상 - naturalSize 유지: \(adjustedNaturalSize)")
        }

        // 전처리 영상을 사용하는 경우, 이미 리사이징되어 있으므로 adjustedNaturalSize를 그대로 사용
        let targetSize: CGSize
        if isFilterAlreadyApplied {
            // 전처리 영상은 이미 리사이징되어 있음
            targetSize = adjustedNaturalSize
            print("📤 [VideoExporter.applyEdits] 전처리 영상 - targetSize = adjustedNaturalSize: \(targetSize)")
        } else {
            // 새로 처리하는 경우 목표 크기 계산 (조정된 naturalSize 기준)
            targetSize = CompressHelper.resizedSizeForiPhoneMax(
                originalWidth: adjustedNaturalSize.width,
                originalHeight: adjustedNaturalSize.height
            )
            print("📤 [VideoExporter.applyEdits] targetSize: \(targetSize)")
        }
        print("📤 [VideoExporter.applyEdits] ====== 편집 적용 종료 ======")


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
                targetSize: targetSize,
                isPortraitFromPHAsset: isPortraitFromPHAsset
            )
        } else if editState.selectedFilter != nil && !isFilterAlreadyApplied {
            // 자막이 없고 필터만 있으면: VideoFilterManager로 필터만 적용
            // (이미 필터가 적용된 경우는 제외)
            videoComposition = await VideoFilterManager.createVideoComposition(
                for: trimmedAsset,
                filter: editState.selectedFilter,
                targetSize: targetSize,
                isPortraitFromPHAsset: isPortraitFromPHAsset
            )
        } else if targetSize != naturalSize {
            // 필터도 자막도 없지만 리사이즈가 필요한 경우
            videoComposition = await CompressHelper.createResizeVideoComposition(
                for: trimmedAsset,
                targetSize: targetSize,
                isPortraitFromPHAsset: isPortraitFromPHAsset
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
        targetSize: CGSize? = nil,
        isPortraitFromPHAsset: Bool
    ) async throws -> AVVideoComposition {
        // 비디오 트랙 가져오기
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.failedToLoadAsset
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let frameDuration = try await videoTrack.load(.minFrameDuration)
        let duration = try await asset.load(.duration)

        // 디버깅 로그
        print("💬 [VideoExporter.applySubtitles] ====== 자막 적용 시작 ======")
        print("💬 [VideoExporter.applySubtitles] 원본 naturalSize: \(naturalSize)")
        print("💬 [VideoExporter.applySubtitles] isPortraitFromPHAsset: \(isPortraitFromPHAsset)")

        // 세로 영상일 때 naturalSize 조정
        let adjustedNaturalSize: CGSize
        if isPortraitFromPHAsset {
            adjustedNaturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            print("💬 [VideoExporter.applySubtitles] 세로 영상 - naturalSize swap: \(adjustedNaturalSize)")
        } else {
            adjustedNaturalSize = naturalSize
        }

        // renderSize 계산
        let renderSize = targetSize ?? adjustedNaturalSize
        print("💬 [VideoExporter.applySubtitles] renderSize: \(renderSize)")

        // 세로 영상일 때 강제로 90도 회전 transform 적용
        let correctedTransform: CGAffineTransform
        if isPortraitFromPHAsset {
            correctedTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
            print("💬 [VideoExporter.applySubtitles] ✅ 세로 영상 - 90도 회전 transform 강제 적용")
        } else {
            correctedTransform = preferredTransform ?? .identity
            print("💬 [VideoExporter.applySubtitles] 가로 영상 - 원본 transform 사용")
        }
        print("💬 [VideoExporter.applySubtitles] ====== 자막 적용 종료 ======")


        // aspect-fit 스케일 계산 (원본 naturalSize 기준)
        let scaleX = renderSize.width / naturalSize.width
        let scaleY = renderSize.height / naturalSize.height
        let scale = min(scaleX, scaleY)
        print("💬 [VideoExporter.applySubtitles] scale: \(scale)")

        // 중앙 정렬을 위한 offset 계산
        let scaledWidth = naturalSize.width * scale
        let scaledHeight = naturalSize.height * scale
        let offsetX: CGFloat
        let offsetY: CGFloat

        if isPortraitFromPHAsset {
            // 세로 영상: 90도 회전 후 중앙 정렬
            offsetX = (renderSize.width - scaledHeight) / 2
            offsetY = (renderSize.height - scaledWidth) / 2
        } else {
            // 가로 영상: 일반 중앙 정렬
            offsetX = (renderSize.width - scaledWidth) / 2
            offsetY = (renderSize.height - scaledHeight) / 2
        }
        print("💬 [VideoExporter.applySubtitles] offset: (\(offsetX), \(offsetY))")

        // 커스텀 compositor를 사용하는 AVMutableVideoComposition 생성
        let composition = AVMutableVideoComposition()
        composition.frameDuration = frameDuration
        composition.renderSize = renderSize
        composition.customVideoCompositorClass = VideoCompositorWithSubtitles.self

        // LayerInstruction 생성
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        // 커스텀 Instruction 생성 (필터, 자막, 리사이징 정보 포함)
        let instruction = SubtitleVideoCompositionInstruction(
            timeRange: CMTimeRange(start: .zero, duration: duration),
            filter: filterToApply,
            subtitles: editState.subtitles,
            trimStartTime: editState.trimStartTime,
            sourceTrackIDs: [NSNumber(value: videoTrack.trackID)],
            layerInstructions: [layerInstruction],
            naturalSize: naturalSize,
            renderSize: renderSize,
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY,
            correctedTransform: correctedTransform,
            isPortraitFromPHAsset: isPortraitFromPHAsset
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
