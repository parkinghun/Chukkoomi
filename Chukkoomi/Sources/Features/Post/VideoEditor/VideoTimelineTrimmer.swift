//
//  VideoTimelineTrimmer.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import SwiftUI
import Photos
import AVFoundation

struct VideoTimelineTrimmer: View {
    let videoAsset: PHAsset
    let duration: Double
    let trimStartTime: Double
    let trimEndTime: Double
    let onTrimStartChanged: (Double) -> Void
    let onTrimEndChanged: (Double) -> Void

    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false

    private let handleWidth: CGFloat = 12
    private let minTrimDuration: Double = 0.1
    private let thumbnailCount = 8

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let startPosition = duration > 0 ? (trimStartTime / duration) * totalWidth : 0
            let endPosition = duration > 0 ? (trimEndTime / duration) * totalWidth : totalWidth
            let selectionWidth = endPosition - startPosition
            let thumbnailWidth = max(0, totalWidth / CGFloat(thumbnailCount))

            ZStack(alignment: .leading) {
                // 배경 타임라인 (비디오 썸네일)
                ThumbnailsView(
                    videoAsset: videoAsset,
                    duration: duration,
                    thumbnailCount: thumbnailCount,
                    thumbnailWidth: thumbnailWidth,
                    height: geometry.size.height,
                    size: geometry.size
                )

                // 선택된 영역 테두리
                SelectionBorderView(
                    width: selectionWidth,
                    offset: startPosition
                )

                // 선택 영역 배경 (어두운 오버레이)
                SelectionOverlayView(
                    startPosition: startPosition,
                    selectionWidth: selectionWidth,
                    endPosition: endPosition,
                    totalWidth: totalWidth
                )

                // 왼쪽 핸들 (시작 시간)
                TrimHandleView(
                    handleWidth: handleWidth,
                    height: geometry.size.height,
                    offset: startPosition
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDraggingStart = true
                            let newPosition = max(0, min(value.location.x, endPosition - handleWidth))
                            let newTime = (newPosition / totalWidth) * duration
                            onTrimStartChanged(newTime)
                        }
                        .onEnded { _ in
                            isDraggingStart = false
                        }
                )

                // 오른쪽 핸들 (종료 시간)
                TrimHandleView(
                    handleWidth: handleWidth,
                    height: geometry.size.height,
                    offset: endPosition - handleWidth
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDraggingEnd = true
                            let newPosition = min(totalWidth, max(value.location.x, startPosition + handleWidth))
                            let newTime = (newPosition / totalWidth) * duration
                            onTrimEndChanged(newTime)
                        }
                        .onEnded { _ in
                            isDraggingEnd = false
                        }
                )
            }
        }
    }

}

// MARK: - Selection Border View
private struct SelectionBorderView: View {
    let width: CGFloat
    let offset: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue, lineWidth: 3)
            )
            .frame(width: width)
            .offset(x: offset)
    }
}

// MARK: - Selection Overlay View
private struct SelectionOverlayView: View {
    let startPosition: CGFloat
    let selectionWidth: CGFloat
    let endPosition: CGFloat
    let totalWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            // 왼쪽 어두운 영역
            if startPosition > 0 {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: startPosition)
            }

            // 선택 영역 (투명)
            Rectangle()
                .fill(Color.clear)
                .frame(width: selectionWidth)

            // 오른쪽 어두운 영역
            if endPosition < totalWidth {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: totalWidth - endPosition)
            }
        }
    }
}

// MARK: - Trim Handle View
private struct TrimHandleView: View {
    let handleWidth: CGFloat
    let height: CGFloat
    let offset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.blue)
                .frame(width: handleWidth)
                .overlay(
                    // 핸들 그립 라인
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 12)
                    }
                )
        }
        .frame(height: height)
        .offset(x: offset)
    }
}

// MARK: - Thumbnails View
private struct ThumbnailsView: View {
    let videoAsset: PHAsset
    let duration: Double
    let thumbnailCount: Int
    let thumbnailWidth: CGFloat
    let height: CGFloat
    let size: CGSize

    @State private var thumbnails: [UIImage] = []
    @State private var isLoadingThumbnails = false

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(0..<thumbnailCount, id: \.self) { index in
                    if index < thumbnails.count {
                        Image(uiImage: thumbnails[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: thumbnailWidth, height: height)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: thumbnailWidth, height: height)
                    }
                }
            }
            .cornerRadius(4)

            // 로딩 인디케이터
            if isLoadingThumbnails {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .cornerRadius(4)
                    .overlay(
                        ProgressView()
                            .tint(.gray)
                    )
            }
        }
        .onAppear {
            if duration > 0 && size.width > 0 {
                loadThumbnails()
            }
        }
        .onChange(of: duration) { _, newDuration in
            if newDuration > 0 && size.width > 0 {
                loadThumbnails()
            }
        }
    }

    // MARK: - Thumbnail Loading
    private func loadThumbnails() {
        guard duration > 0 else { return }

        // 로딩 시작
        isLoadingThumbnails = true

        // PHAsset에서 AVAsset 로드
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestAVAsset(forVideo: videoAsset, options: options) { avAsset, _, _ in
            guard let avAsset = avAsset else {
                Task { @MainActor in
                    self.isLoadingThumbnails = false
                }
                return
            }

            let generator = AVAssetImageGenerator(asset: avAsset)
            generator.appliesPreferredTrackTransform = true
            // 디스플레이 스케일을 고려하여 더 높은 해상도로 생성 (3배)
            let scale: CGFloat = 3.0
            let thumbnailWidth = (size.width / CGFloat(thumbnailCount)) * scale
            let thumbnailHeight = size.height * scale
            generator.maximumSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
            // 정확한 프레임 추출을 위한 설정
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            var generatedThumbnails: [UIImage] = []
            let interval = duration / Double(thumbnailCount)

            for i in 0..<thumbnailCount {
                let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)

                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    let image = UIImage(cgImage: cgImage)
                    generatedThumbnails.append(image)
                }
            }

            Task { @MainActor in
                self.thumbnails = generatedThumbnails
                self.isLoadingThumbnails = false
            }
        }
    }
}
