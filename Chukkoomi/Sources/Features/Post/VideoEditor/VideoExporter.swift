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

        // naturalSize가 가로 방향인지 확인
        let isNaturalSizePortrait = naturalSize.width < naturalSize.height
        print("📤 [VideoExporter.applyEdits] isNaturalSizePortrait: \(isNaturalSizePortrait)")

        // 세로 영상인데 naturalSize가 가로로 나온 경우 swap
        let adjustedNaturalSize: CGSize
        if isPortraitFromPHAsset && !isNaturalSizePortrait {
            // 세로 영상인데 naturalSize가 가로 → swap
            adjustedNaturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            print("📤 [VideoExporter.applyEdits] naturalSize swap: \(adjustedNaturalSize)")
        } else {
            adjustedNaturalSize = naturalSize
            print("📤 [VideoExporter.applyEdits] naturalSize 유지: \(adjustedNaturalSize)")
        }

        // 목표 크기 계산 (조정된 naturalSize 기준)
        let targetSize: CGSize
        if isFilterAlreadyApplied {
            // 전처리 영상은 이미 리사이징되어 있음
            targetSize = adjustedNaturalSize
            print("📤 [VideoExporter.applyEdits] 전처리 영상 - targetSize = adjustedNaturalSize: \(targetSize)")
        } else {
            // 새로 처리하는 경우 목표 크기 계산
            targetSize = CompressHelper.resizedSizeForiPhoneMax(
                originalWidth: adjustedNaturalSize.width,
                originalHeight: adjustedNaturalSize.height
            )
            print("📤 [VideoExporter.applyEdits] targetSize: \(targetSize)")
        }
        print("📤 [VideoExporter.applyEdits] ====== 편집 적용 종료 ======")


        // 3) Filter와 Subtitles 처리
        let videoComposition: AVVideoComposition?

        if !editState.subtitles.isEmpty || (editState.selectedFilter != nil && !isFilterAlreadyApplied) {
            // 자막이 있거나 필터가 있으면: 커스텀 compositor 사용
            // (자막 없이 필터만 있는 경우도 커스텀 compositor로 처리하여 회전 문제 방지)
            let filterToApply = isFilterAlreadyApplied ? nil : editState.selectedFilter
            videoComposition = try await applySubtitles(
                to: trimmedAsset,
                editState: editState,
                filterToApply: filterToApply,
                targetSize: targetSize,
                isPortraitFromPHAsset: isPortraitFromPHAsset
            )
        } else if targetSize != adjustedNaturalSize {
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

        // 원본 트랙의 preferredTransform 복사
        if let preferredTransform = try? await videoTrack.load(.preferredTransform) {
            compositionVideoTrack.preferredTransform = preferredTransform
            print("✂️ [VideoExporter.applyTrim] 원본 preferredTransform: \(preferredTransform)")
            print("✂️ [VideoExporter.applyTrim] composition 트랙에 복사 완료")
        }
        print("✂️ [VideoExporter.applyTrim] composition 트랙 preferredTransform: \(compositionVideoTrack.preferredTransform)")

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

        print("💬 [VideoExporter.applySubtitles] 트랙 정보:")
        print("💬 [VideoExporter.applySubtitles] 진입 시 트랙 preferredTransform: \(preferredTransform)")

        // 커스텀 compositor가 픽셀 회전을 수행하므로, composition 트랙의 preferredTransform을 identity로 재설정
        // (이미 회전된 픽셀이므로 추가 회전 방지)
        if let composition = asset as? AVMutableComposition,
           let compositionVideoTrack = composition.tracks(withMediaType: .video).first as? AVMutableCompositionTrack {
            print("💬 [VideoExporter.applySubtitles] composition 트랙 발견 - preferredTransform을 identity로 재설정")
            print("💬 [VideoExporter.applySubtitles] 재설정 전: \(compositionVideoTrack.preferredTransform)")
            compositionVideoTrack.preferredTransform = .identity
            print("💬 [VideoExporter.applySubtitles] 재설정 후: \(compositionVideoTrack.preferredTransform)")
        } else {
            print("💬 [VideoExporter.applySubtitles] composition 트랙 아님 - preferredTransform 재설정 스킵")
        }
        let frameDuration = try await videoTrack.load(.minFrameDuration)
        let duration = try await asset.load(.duration)

        // 디버깅 로그
        print("💬 [VideoExporter.applySubtitles] ====== 자막 적용 시작 ======")
        print("💬 [VideoExporter.applySubtitles] 원본 naturalSize: \(naturalSize)")
        print("💬 [VideoExporter.applySubtitles] isPortraitFromPHAsset: \(isPortraitFromPHAsset)")
        print("💬 [VideoExporter.applySubtitles] targetSize 파라미터: \(targetSize ?? .zero)")

        // naturalSize가 가로 방향인지 확인
        let isNaturalSizePortrait = naturalSize.width < naturalSize.height
        print("💬 [VideoExporter.applySubtitles] isNaturalSizePortrait: \(isNaturalSizePortrait)")

        // 세로 영상인데 naturalSize가 가로로 나온 경우 swap
        let adjustedNaturalSize: CGSize
        if isPortraitFromPHAsset && !isNaturalSizePortrait {
            adjustedNaturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            print("💬 [VideoExporter.applySubtitles] naturalSize swap: \(adjustedNaturalSize)")
        } else {
            adjustedNaturalSize = naturalSize
            print("💬 [VideoExporter.applySubtitles] naturalSize 유지: \(adjustedNaturalSize)")
        }

        // renderSize 계산
        let renderSize = targetSize ?? adjustedNaturalSize
        print("💬 [VideoExporter.applySubtitles] renderSize: \(renderSize)")

        // renderSize 방향 확인
        let isRenderSizePortrait = renderSize.width < renderSize.height
        print("💬 [VideoExporter.applySubtitles] isRenderSizePortrait: \(isRenderSizePortrait)")

        // 원본 비디오의 preferredTransform을 그대로 사용
        // (커스텀 compositor가 이를 먼저 적용하여 raw 픽셀을 실제 방향으로 변환)
        let correctedTransform = preferredTransform ?? .identity
        print("💬 [VideoExporter.applySubtitles] 원본 preferredTransform 사용: \(correctedTransform)")
        print("💬 [VideoExporter.applySubtitles] ====== 자막 적용 종료 ======")


        // aspect-fit 스케일 계산 (adjustedNaturalSize 기준 - preferredTransform 적용 후 크기)
        let scaleX = renderSize.width / adjustedNaturalSize.width
        let scaleY = renderSize.height / adjustedNaturalSize.height
        let scale = min(scaleX, scaleY)
        print("💬 [VideoExporter.applySubtitles] scale: \(scale) (scaleX: \(scaleX), scaleY: \(scaleY))")

        // 중앙 정렬을 위한 offset 계산 (adjustedNaturalSize 기준)
        let scaledWidth = adjustedNaturalSize.width * scale
        let scaledHeight = adjustedNaturalSize.height * scale
        print("💬 [VideoExporter.applySubtitles] scaledWidth: \(scaledWidth), scaledHeight: \(scaledHeight)")

        let offsetX = (renderSize.width - scaledWidth) / 2
        let offsetY = (renderSize.height - scaledHeight) / 2
        print("💬 [VideoExporter.applySubtitles] offset: (\(offsetX), \(offsetY))")

        // 커스텀 compositor를 사용하는 AVMutableVideoComposition 생성
        let composition = AVMutableVideoComposition()
        composition.frameDuration = frameDuration
        composition.renderSize = renderSize
        composition.customVideoCompositorClass = VideoCompositorWithSubtitles.self

        // LayerInstruction 생성
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        // 커스텀 compositor가 픽셀 회전을 수행하므로, 출력 트랙은 추가 회전이 필요 없음
        // 따라서 identity transform 설정 (이미 회전된 픽셀이므로)
        layerInstruction.setTransform(.identity, at: .zero)

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
        print("📹 [VideoExporter.exportComposition] ====== Export 시작 ======")

        // composition 트랙 정보 로깅
        if let tracks = try? await composition.loadTracks(withMediaType: .video) {
            for (index, track) in tracks.enumerated() {
                if let naturalSize = try? await track.load(.naturalSize),
                   let preferredTransform = try? await track.load(.preferredTransform) {
                    print("📹 [VideoExporter.exportComposition] 트랙 \(index):")
                    print("📹 [VideoExporter.exportComposition]   naturalSize: \(naturalSize)")
                    print("📹 [VideoExporter.exportComposition]   preferredTransform: \(preferredTransform)")
                }
            }
        }

        if let videoComposition = videoComposition {
            print("📹 [VideoExporter.exportComposition] videoComposition:")
            print("📹 [VideoExporter.exportComposition]   renderSize: \(videoComposition.renderSize)")
            print("📹 [VideoExporter.exportComposition]   customCompositorClass: \(String(describing: videoComposition.customVideoCompositorClass))")
        }
        print("📹 [VideoExporter.exportComposition] ====== Export 설정 완료 ======")

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
