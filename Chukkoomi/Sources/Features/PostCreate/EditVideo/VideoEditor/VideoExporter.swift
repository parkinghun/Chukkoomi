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

        let (composition, videoComposition, audioMix) = try await applyEdits(
            to: avAsset,
            editState: editState,
            isFilterAlreadyApplied: isFilterAlreadyApplied
        )

        let exportedURL = try await exportComposition(
            composition,
            videoComposition: videoComposition,
            audioMix: audioMix,
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
    ) async throws -> (AVAsset, AVVideoComposition?, AVAudioMix?) {
        let composition = AVMutableComposition()

        // 1) Trim만 수행
        let trimmedAsset = try await applyTrim(to: asset, editState: editState, composition: composition)

        // 2) 배경음악 추가
        var audioMix: AVAudioMix? = nil
        if !editState.backgroundMusics.isEmpty {
            audioMix = try await addBackgroundMusic(to: composition, editState: editState)
        }

        // 3) 필터, 자막, 리사이즈 처리
        let videoComposition: AVVideoComposition?

        // AnimeGAN 필터이고 자막이 없고 아직 적용되지 않았으면 VideoFilterManager 사용
        if editState.selectedFilter == .animeGANHayao && editState.subtitles.isEmpty && !isFilterAlreadyApplied {
            videoComposition = try await createAnimeGANComposition(for: trimmedAsset)
        } else if !editState.subtitles.isEmpty || (editState.selectedFilter != nil && !isFilterAlreadyApplied) {
            // 자막이나 다른 필터가 있으면: 커스텀 compositor 사용
            let filterToApply = isFilterAlreadyApplied ? nil : editState.selectedFilter
            videoComposition = try await createVideoComposition(
                for: trimmedAsset,
                editState: editState,
                filterToApply: filterToApply
            )
        } else {
            // 필터도 자막도 없으면: 리사이즈만 수행
            videoComposition = try await createResizeOnlyComposition(for: trimmedAsset)
        }

        return (trimmedAsset, videoComposition, audioMix)
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

        // 비디오 트랙 추가
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            return composition
        }

        try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)

        // 원본 preferredTransform 유지 (중요!)
        if let preferredTransform = try? await videoTrack.load(.preferredTransform) {
            compositionVideoTrack.preferredTransform = preferredTransform
        }

        // 오디오 트랙 추가 (있으면)
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }

        return composition
    }

    /// 필터, 자막, 리사이즈를 모두 처리하는 videoComposition 생성
    private func createVideoComposition(
        for asset: AVAsset,
        editState: EditVideoFeature.EditState,
        filterToApply: VideoFilter?
    ) async throws -> AVVideoComposition {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.failedToLoadAsset
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let frameDuration = try await videoTrack.load(.minFrameDuration)
        let duration = try await asset.load(.duration)

        // preferredTransform을 적용한 실제 비디오 크기 계산
        let videoSize = sizeAfterApplyingTransform(naturalSize: naturalSize, transform: preferredTransform)

        // 목표 크기 계산 (videoSize 기준)
        let targetSize = CompressHelper.resizedSizeForiPhoneMax(
            originalWidth: videoSize.width,
            originalHeight: videoSize.height
        )

        // Composition 트랙의 preferredTransform을 identity로 재설정
        // (compositor가 이미 회전을 처리하므로 중복 방지)
        if let composition = asset as? AVMutableComposition,
           let compositionVideoTrack = composition.tracks(withMediaType: .video).first {
            compositionVideoTrack.preferredTransform = .identity
        }

        // AVMutableVideoComposition 생성
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = frameDuration
        videoComposition.renderSize = targetSize  // 최종 크기 (세로)
        videoComposition.customVideoCompositorClass = VideoCompositor.self

        // LayerInstruction 생성
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(.identity, at: .zero)

        // 커스텀 Instruction 생성
        let instruction = SubtitleVideoCompositionInstruction(
            timeRange: CMTimeRange(start: .zero, duration: duration),
            filter: filterToApply,
            subtitles: editState.subtitles,
            trimStartTime: editState.trimStartTime,
            sourceTrackIDs: [NSNumber(value: videoTrack.trackID)],
            layerInstructions: [layerInstruction],
            preferredTransform: preferredTransform,
            renderSize: targetSize
        )

        videoComposition.instructions = [instruction]

        return videoComposition
    }

    /// AnimeGAN 필터를 적용하는 videoComposition 생성 (VideoFilterManager 사용)
    private func createAnimeGANComposition(for asset: AVAsset) async throws -> AVVideoComposition? {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)

        // preferredTransform을 적용한 실제 비디오 크기
        let videoSize = sizeAfterApplyingTransform(naturalSize: naturalSize, transform: preferredTransform)

        // 목표 크기 계산
        let targetSize = CompressHelper.resizedSizeForiPhoneMax(
            originalWidth: videoSize.width,
            originalHeight: videoSize.height
        )

        // portrait 여부 확인
        let isPortrait = videoSize.height > videoSize.width

        // VideoFilterManager를 사용하여 AnimeGAN 필터 적용
        return await VideoFilterManager.createVideoComposition(
            for: asset,
            filter: .animeGANHayao,
            targetSize: targetSize,
            isPortraitFromPHAsset: isPortrait
        )
    }

    /// 리사이즈만 수행하는 videoComposition 생성
    private func createResizeOnlyComposition(for asset: AVAsset) async throws -> AVVideoComposition? {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)

        // preferredTransform을 적용한 실제 비디오 크기
        let videoSize = sizeAfterApplyingTransform(naturalSize: naturalSize, transform: preferredTransform)

        // 목표 크기 계산
        let targetSize = CompressHelper.resizedSizeForiPhoneMax(
            originalWidth: videoSize.width,
            originalHeight: videoSize.height
        )

        // 리사이즈가 필요 없으면 nil 반환
        if targetSize == videoSize {
            return nil
        }

        // CompressHelper로 리사이즈만 수행
        return await CompressHelper.createResizeVideoComposition(
            for: asset,
            targetSize: targetSize
        )
    }

    /// preferredTransform을 적용한 실제 비디오 크기 계산
    private func sizeAfterApplyingTransform(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        // 90도 또는 270도 회전 여부 확인
        let isRotated90Degrees = transform.b != 0 || transform.c != 0

        if isRotated90Degrees {
            // 회전되어 있으면 width와 height swap
            return CGSize(width: naturalSize.height, height: naturalSize.width)
        } else {
            return naturalSize
        }
    }

    /// 배경음악을 composition에 추가하고 AVAudioMix 반환
    private func addBackgroundMusic(
        to composition: AVMutableComposition,
        editState: EditVideoFeature.EditState
    ) async throws -> AVAudioMix? {
        var audioMixInputParameters: [AVMutableAudioMixInputParameters] = []

        for music in editState.backgroundMusics {
            // 배경음악 asset 로드
            let musicAsset = AVAsset(url: music.musicURL)
            guard let musicTrack = try await musicAsset.loadTracks(withMediaType: .audio).first else {
                continue
            }

            // 음악 duration 로드
            let musicDuration = try await musicAsset.load(.duration)

            // 배경음악을 추가할 트랙 생성
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                continue
            }

            // 배경음악의 시작 시간
            let startTime = CMTime(seconds: music.startTime, preferredTimescale: 600)
            let endTime = CMTime(seconds: music.endTime, preferredTimescale: 600)
            let musicRangeDuration = CMTimeSubtract(endTime, startTime)

            // 설정한 범위와 음악 파일의 실제 길이 중 짧은 것만큼만 삽입
            let actualDuration = min(musicDuration, musicRangeDuration)
            let sourceRange = CMTimeRange(start: .zero, duration: actualDuration)
            try compositionAudioTrack.insertTimeRange(sourceRange, of: musicTrack, at: startTime)

            // 볼륨 설정을 위한 AudioMixInputParameters 생성
            let inputParameters = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
            inputParameters.setVolume(music.volume, at: .zero)
            audioMixInputParameters.append(inputParameters)
        }

        // AVAudioMix 생성
        guard !audioMixInputParameters.isEmpty else {
            return nil
        }

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioMixInputParameters
        return audioMix
    }


    private func exportComposition(
        _ composition: AVAsset,
        videoComposition: AVVideoComposition?,
        audioMix: AVAudioMix?,
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

        if let audioMix = audioMix {
            exportSession.audioMix = audioMix
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
