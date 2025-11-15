//
//  EditVideoView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import SwiftUI
import ComposableArchitecture
import AVKit
import Photos

struct EditVideoView: View {
    let store: StoreOf<EditVideoFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 커스텀 비디오 플레이어
                CustomVideoPlayerView(
                    asset: viewStore.videoAsset,
                    isPlaying: viewStore.isPlaying,
                    seekTrigger: viewStore.seekTrigger,
                    selectedFilter: viewStore.editState.selectedFilter,
                    onTimeUpdate: { time in viewStore.send(.updateCurrentTime(time)) },
                    onDurationUpdate: { duration in viewStore.send(.updateDuration(duration)) },
                    onSeekCompleted: { viewStore.send(.seekCompleted) },
                    onFilterApplied: { viewStore.send(.filterApplied) }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .overlay {
                    if viewStore.isApplyingFilter {
                        FilterApplyingOverlayView()
                    }
                }

                // 컨트롤 UI
                VideoControlsView(
                    currentTime: viewStore.currentTime,
                    duration: viewStore.duration,
                    isPlaying: viewStore.isPlaying,
                    onSeekBackward: { viewStore.send(.seekBackward) },
                    onPlayPause: { viewStore.send(.playPauseButtonTapped) },
                    onSeekForward: { viewStore.send(.seekForward) }
                )
                .padding(.top, AppPadding.medium)

                Spacer()

                // 타임라인 트리머
                VideoTimelineTrimmer(
                    videoAsset: viewStore.videoAsset,
                    duration: viewStore.duration,
                    trimStartTime: viewStore.editState.trimStartTime,
                    trimEndTime: viewStore.editState.trimEndTime,
                    onTrimStartChanged: { time in
                        viewStore.send(.updateTrimStartTime(time))
                    },
                    onTrimEndChanged: { time in
                        viewStore.send(.updateTrimEndTime(time))
                    }
                )
                .frame(height: 60)
                .padding(.horizontal, AppPadding.large)

                // 필터 선택
                FilterSelectionView(
                    selectedFilter: viewStore.editState.selectedFilter,
                    onFilterSelected: { filter in
                        viewStore.send(.filterSelected(filter))
                    }
                )
                .padding(.top, AppPadding.medium)

                Spacer()
            }
            .navigationTitle("영상 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewStore.send(.nextButtonTapped)
                    } label: {
                        Text("다음")
                            .foregroundStyle(.black)
                    }
                    .disabled(viewStore.isExporting)
                }
            }
            .overlay {
                if viewStore.isExporting {
                    ExportingOverlayView(progress: viewStore.exportProgress)
                }
            }
        }
    }
}

// MARK: - Filter Applying Overlay View
private struct FilterApplyingOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: AppPadding.medium) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("필터 적용 중...")
                    .font(.appBody)
                    .foregroundStyle(.white)
            }
            .padding(AppPadding.large * 2)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
        }
    }
}

// MARK: - Exporting Overlay View
private struct ExportingOverlayView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: AppPadding.large) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("영상 내보내는 중...")
                    .font(.appSubTitle)
                    .foregroundStyle(.white)

                Text("\(Int(progress * 100))%")
                    .font(.appBody)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(AppPadding.large * 2)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
        }
    }
}

// MARK: - Video Controls View
private struct VideoControlsView: View {
    let currentTime: Double
    let duration: Double
    let isPlaying: Bool
    let onSeekBackward: () -> Void
    let onPlayPause: () -> Void
    let onSeekForward: () -> Void

    var body: some View {
        ZStack {
            // 현재 시간 / 전체 시간 (왼쪽)
            HStack {
                Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                    .font(.appBody)
                    .foregroundStyle(.black)
                Spacer()
            }
            .padding(.horizontal, AppPadding.large)

            // 재생 컨트롤 버튼들
            HStack(spacing: AppPadding.large) {
                // 10초 전
                Button {
                    onSeekBackward()
                } label: {
                    AppIcon.backward
                        .font(.system(size: 20))
                        .foregroundStyle(.black)
                }

                // 재생/일시정지
                Button {
                    onPlayPause()
                } label: {
                    Group {
                        if isPlaying {
                            AppIcon.pause
                        } else {
                            AppIcon.play
                        }
                    }
                    .font(.system(size: 28))
                    .foregroundStyle(.black)
                }

                // 10초 후
                Button {
                    onSeekForward()
                } label: {
                    AppIcon.forward
                        .font(.system(size: 20))
                        .foregroundStyle(.black)
                }
            }
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Filter Selection View
private struct FilterSelectionView: View {
    let selectedFilter: EditVideoFeature.FilterType?
    let onFilterSelected: (EditVideoFeature.FilterType) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppPadding.medium) {
                ForEach(EditVideoFeature.FilterType.allCases, id: \.self) { filter in
                    FilterButton(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        action: {
                            onFilterSelected(filter)
                        }
                    )
                }
            }
            .padding(.horizontal, AppPadding.large)
        }
    }
}

// MARK: - Filter Button
private struct FilterButton: View {
    let filter: EditVideoFeature.FilterType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // 필터 미리보기 (TODO: 나중에 실제 필터 적용된 썸네일로 변경)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )

                // 필터 이름
                Text(filter.displayName)
                    .font(.appCaption)
                    .foregroundStyle(isSelected ? .blue : .black)
            }
        }
    }
}

// MARK: - Custom Video Player
struct CustomVideoPlayerView: UIViewRepresentable {
    let asset: PHAsset
    let isPlaying: Bool
    let seekTrigger: EditVideoFeature.SeekDirection?
    let selectedFilter: EditVideoFeature.FilterType?
    let onTimeUpdate: (Double) -> Void
    let onDurationUpdate: (Double) -> Void
    let onSeekCompleted: () -> Void
    let onFilterApplied: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        context.coordinator.loadVideo(for: asset, in: view)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 재생/일시정지 처리
        if isPlaying {
            context.coordinator.play()
        } else {
            context.coordinator.pause()
        }

        // Seek 처리
        if let seekTrigger = seekTrigger {
            switch seekTrigger {
            case .backward:
                context.coordinator.seekBackward()
            case .forward:
                context.coordinator.seekForward()
            }
            DispatchQueue.main.async {
                onSeekCompleted()
            }
        }

        // 필터 업데이트
        context.coordinator.updateFilter(selectedFilter, onComplete: onFilterApplied)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTimeUpdate: onTimeUpdate,
            onDurationUpdate: onDurationUpdate
        )
    }

    final class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var timeObserver: Any?
        var currentAVAsset: AVAsset?
        var lastAppliedFilter: EditVideoFeature.FilterType?
        let onTimeUpdate: (Double) -> Void
        let onDurationUpdate: (Double) -> Void

        init(
            onTimeUpdate: @escaping (Double) -> Void,
            onDurationUpdate: @escaping (Double) -> Void
        ) {
            self.onTimeUpdate = onTimeUpdate
            self.onDurationUpdate = onDurationUpdate
        }

        func loadVideo(for asset: PHAsset, in view: UIView) {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
                guard let self, let avAsset else { return }

                DispatchQueue.main.async {
                    self.currentAVAsset = avAsset
                    let playerItem = AVPlayerItem(asset: avAsset)

                    self.player = AVPlayer(playerItem: playerItem)
                    self.playerLayer = AVPlayerLayer(player: self.player)
                    self.playerLayer?.frame = view.bounds
                    self.playerLayer?.videoGravity = .resizeAspect

                    if let playerLayer = self.playerLayer {
                        view.layer.addSublayer(playerLayer)
                    }

                    // Duration 업데이트
                    Task {
                        if let duration = try? await avAsset.load(.duration) {
                            let durationSeconds = duration.seconds
                            if durationSeconds.isFinite {
                                await MainActor.run {
                                    self.onDurationUpdate(durationSeconds)
                                }
                            }
                        }
                    }

                    // 시간 업데이트 observer 추가
                    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                    self.timeObserver = self.player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                        let currentTime = time.seconds
                        if currentTime.isFinite {
                            self?.onTimeUpdate(currentTime)
                        }
                    }
                }
            }
        }

        func play() {
            player?.play()
        }

        func pause() {
            player?.pause()
        }

        func seekBackward() {
            guard let player = player else { return }
            let currentTime = player.currentTime()
            let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 600))
            let clampedTime = max(newTime, .zero)
            player.seek(to: clampedTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        func seekForward() {
            guard let player = player, let duration = player.currentItem?.duration else { return }
            let currentTime = player.currentTime()
            let newTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 600))
            let clampedTime = min(newTime, duration)
            player.seek(to: clampedTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        func updateFilter(_ filterType: EditVideoFeature.FilterType?, onComplete: @escaping () -> Void) {
            // 이미 적용된 필터와 같으면 중복 호출 방지
            if lastAppliedFilter == filterType {
                return
            }

            lastAppliedFilter = filterType

            guard let playerItem = player?.currentItem,
                  let avAsset = currentAVAsset else {
                DispatchQueue.main.async {
                    onComplete()
                }
                return
            }

            Task {
                // 필터가 없으면 videoComposition 제거
                guard let filterType = filterType,
                      let filterName = filterType.ciFilterName else {
                    await MainActor.run {
                        playerItem.videoComposition = nil
                        onComplete()
                    }
                    return
                }

                // 비디오 트랙 가져오기
                guard let videoTrack = try? await avAsset.loadTracks(withMediaType: .video).first else {
                    await MainActor.run {
                        onComplete()
                    }
                    return
                }

                let naturalSize = try? await videoTrack.load(.naturalSize)
                let preferredTransform = try? await videoTrack.load(.preferredTransform)

                // CIFilter 생성
                let filter = CIFilter(name: filterName)

                // AVVideoComposition 생성
                let composition = AVMutableVideoComposition(
                    asset: avAsset,
                    applyingCIFiltersWithHandler: { request in
                        let source = request.sourceImage.clampedToExtent()
                        filter?.setValue(source, forKey: kCIInputImageKey)

                        let output = filter?.outputImage ?? source
                        request.finish(with: output, context: nil)
                    }
                )

                if let naturalSize = naturalSize {
                    composition.renderSize = naturalSize
                }

                if let preferredTransform = preferredTransform {
                    // Transform 처리 (회전, 플립 등)
                    let videoInfo = orientation(from: preferredTransform)
                    var isPortrait = false
                    switch videoInfo.orientation {
                    case .up, .upMirrored, .down, .downMirrored:
                        isPortrait = false
                    case .left, .leftMirrored, .right, .rightMirrored:
                        isPortrait = true
                    @unknown default:
                        isPortrait = false
                    }

                    if isPortrait, let naturalSize = naturalSize {
                        composition.renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                    }
                }

                // 메인 스레드에서 videoComposition 적용
                await MainActor.run {
                    playerItem.videoComposition = composition
                    // 약간의 딜레이 후 완료 콜백 호출 (필터 적용이 안정화되도록)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }
            }
        }

        // 비디오 orientation 확인 헬퍼
        private func orientation(from transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
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

        deinit {
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            player?.pause()
        }
    }
}
