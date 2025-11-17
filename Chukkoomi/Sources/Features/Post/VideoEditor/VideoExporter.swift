//
//  VideoExporter.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import UIKit
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

    /// 비디오를 편집하고 내보내기
    /// - Parameters:
    ///   - asset: 원본 비디오 PHAsset
    ///   - editState: 적용할 편집 정보
    ///   - progressHandler: 진행률 콜백 (0.0 ~ 1.0)
    /// - Returns: 내보낸 비디오의 임시 파일 URL
    func export(
        asset: PHAsset,
        editState: EditVideoFeature.EditState,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        // 1. PHAsset에서 AVAsset 가져오기
        let avAsset = try await loadAVAsset(from: asset)

        // 2. 편집 적용하여 AVAsset Composition 생성
        let (composition, videoComposition) = try await applyEdits(to: avAsset, editState: editState)

        // 3. 최종 영상 내보내기
        let exportedURL = try await exportComposition(
            composition,
            videoComposition: videoComposition,
            progressHandler: progressHandler
        )

        return exportedURL
    }

    // MARK: - Private Methods

    /// PHAsset에서 AVAsset 로드
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

    /// 편집 적용 (Trim, Filters, Subtitles 등)
    private func applyEdits(
        to asset: AVAsset,
        editState: EditVideoFeature.EditState
    ) async throws -> (AVAsset, AVVideoComposition?) {
        // AVMutableComposition 생성
        let composition = AVMutableComposition()

        // 1. Trim 적용
        let trimmedAsset = try await applyTrim(to: asset, editState: editState, composition: composition)

        // 2. Filters 적용
        let videoComposition = try await applyFilter(to: trimmedAsset, filterType: editState.selectedFilter)

        // TODO: 3. Subtitles 적용
        // let subtitledAsset = try await applySubtitles(to: filteredAsset, subtitles: editState.subtitles)

        return (trimmedAsset, videoComposition)
    }

    /// Trim 적용
    private func applyTrim(
        to asset: AVAsset,
        editState: EditVideoFeature.EditState,
        composition: AVMutableComposition
    ) async throws -> AVAsset {
        // 시간 범위 설정
        let startTime = CMTime(seconds: editState.trimStartTime, preferredTimescale: 600)

        // endTime이 infinity이거나 비정상적으로 큰 경우 asset의 실제 duration 사용
        let assetDuration = try await asset.load(.duration)
        let actualEndTime: CMTime
        if editState.trimEndTime.isInfinite || editState.trimEndTime > assetDuration.seconds {
            actualEndTime = assetDuration
        } else {
            actualEndTime = CMTime(seconds: editState.trimEndTime, preferredTimescale: 600)
        }

        let timeRange = CMTimeRange(start: startTime, end: actualEndTime)

        // 비디오 트랙 추가
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

        // 오디오 트랙 추가 (있는 경우)
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

    /// Filter 적용
    private func applyFilter(
        to asset: AVAsset,
        filterType: VideoFilter?
    ) async throws -> AVVideoComposition? {
        // VideoFilterManager를 사용하여 필터 적용
        return await VideoFilterManager.createVideoComposition(
            for: asset,
            filter: filterType
        )
    }

    /// Composition을 파일로 내보내기
    private func exportComposition(
        _ composition: AVAsset,
        videoComposition: AVVideoComposition?,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        // Export Session 생성
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.failedToCreateExportSession
        }

        // 하드웨어 가속 활성화
        exportSession.shouldOptimizeForNetworkUse = false  // 로컬 재생 최적화

        // 비디오 컴포지션 설정 (필터가 있는 경우)
        if let videoComposition = videoComposition {
            exportSession.videoComposition = videoComposition
        }

        // 출력 파일 URL 설정 (Caches 디렉토리 사용)
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw ExportError.failedToCreateExportSession
        }

        let videosCacheDirectory = cachesDirectory.appendingPathComponent("ExportedVideos", isDirectory: true)

        // 디렉토리가 없으면 생성
        if !FileManager.default.fileExists(atPath: videosCacheDirectory.path) {
            try? FileManager.default.createDirectory(at: videosCacheDirectory, withIntermediateDirectories: true)
        }

        let outputURL = videosCacheDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        // 기존 파일이 있으면 삭제
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        // 진행률 관찰 Task
        nonisolated(unsafe) let session = exportSession
        let progressTask = Task {
            while !Task.isCancelled {
                let progress = session.progress
                progressHandler(Double(progress))

                if progress >= 1.0 {
                    break
                }

                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            }
        }

        // 내보내기 실행
        await exportSession.export()

        progressTask.cancel()

        // 결과 확인
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
