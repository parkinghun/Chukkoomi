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
                    onTimeUpdate: { time in viewStore.send(.updateCurrentTime(time)) },
                    onDurationUpdate: { duration in viewStore.send(.updateDuration(duration)) },
                    onSeekCompleted: { viewStore.send(.seekCompleted) }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 300)

                // 컨트롤 UI
                videoControls(viewStore: viewStore)
                    .padding(.top, AppPadding.medium)

                Spacer()

                // 임시 편집 UI 플레이스홀더
                Text("영상 편집 화면")
                    .font(.appTitle)
                    .foregroundStyle(.gray)

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
                }
            }
        }
    }

    // MARK: - Video Controls
    private func videoControls(viewStore: ViewStoreOf<EditVideoFeature>) -> some View {
        ZStack {
            // 현재 시간 / 전체 시간 (왼쪽)
            HStack {
                Text("\(formatTime(viewStore.currentTime)) / \(formatTime(viewStore.duration))")
                    .font(.appBody)
                    .foregroundStyle(.black)
                Spacer()
            }
            .padding(.horizontal, AppPadding.large)

            // 재생 컨트롤 버튼들
            HStack(spacing: AppPadding.large) {
                // 10초 전
                Button {
                    viewStore.send(.seekBackward)
                } label: {
                    AppIcon.backward
                        .font(.system(size: 20))
                        .foregroundStyle(.black)
                }

                // 재생/일시정지
                Button {
                    viewStore.send(.playPauseButtonTapped)
                } label: {
                    Group {
                        if viewStore.isPlaying {
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
                    viewStore.send(.seekForward)
                } label: {
                    AppIcon.forward
                        .font(.system(size: 20))
                        .foregroundStyle(.black)
                }
            }
        }
    }

    // MARK: - Helper
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Custom Video Player
struct CustomVideoPlayerView: UIViewRepresentable {
    let asset: PHAsset
    let isPlaying: Bool
    let seekTrigger: EditVideoFeature.SeekDirection?
    let onTimeUpdate: (Double) -> Void
    let onDurationUpdate: (Double) -> Void
    let onSeekCompleted: () -> Void

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

            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { [weak self] playerItem, _ in
                guard let self, let playerItem else { return }

                DispatchQueue.main.async {
                    self.player = AVPlayer(playerItem: playerItem)
                    self.playerLayer = AVPlayerLayer(player: self.player)
                    self.playerLayer?.frame = view.bounds
                    self.playerLayer?.videoGravity = .resizeAspect

                    if let playerLayer = self.playerLayer {
                        view.layer.addSublayer(playerLayer)
                    }

                    // Duration 업데이트
                    Task {
                        if let duration = try? await playerItem.asset.load(.duration) {
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

        deinit {
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            player?.pause()
        }
    }
}
