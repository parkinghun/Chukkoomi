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
@preconcurrency import CoreImage

struct EditVideoView: View {
    let store: StoreOf<EditVideoFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 커스텀 비디오 플레이어 (16:9 비율)
                Color.black
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        CustomVideoPlayerView(
                            asset: viewStore.videoAsset,
                            preProcessedVideoURL: viewStore.preProcessedVideoURL,
                            isPlaying: viewStore.isPlaying,
                            seekTrigger: viewStore.seekTrigger,
                            selectedFilter: viewStore.editState.selectedFilter,
                            onTimeUpdate: { time in viewStore.send(.updateCurrentTime(time)) },
                            onDurationUpdate: { duration in viewStore.send(.updateDuration(duration)) },
                            onSeekCompleted: { viewStore.send(.seekCompleted) },
                            onFilterApplied: { viewStore.send(.filterApplied) }
                        )
                    }
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

                // 가로 스크롤 가능한 타임라인 편집 영역
                VideoTimelineEditor(
                    videoAsset: viewStore.videoAsset,
                    duration: viewStore.duration,
                    currentTime: viewStore.currentTime,
                    trimStartTime: viewStore.editState.trimStartTime,
                    trimEndTime: viewStore.editState.trimEndTime,
                    onTrimStartChanged: { time in
                        viewStore.send(.updateTrimStartTime(time))
                    },
                    onTrimEndChanged: { time in
                        viewStore.send(.updateTrimEndTime(time))
                    }
                )
                .frame(height: 100)

                // 필터 선택 (독립 영역)
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

// MARK: - Video Timeline Editor (가로 스크롤 가능)
private struct VideoTimelineEditor: UIViewRepresentable {
    let videoAsset: PHAsset
    let duration: Double
    let currentTime: Double
    let trimStartTime: Double
    let trimEndTime: Double
    let onTrimStartChanged: (Double) -> Void
    let onTrimEndChanged: (Double) -> Void

    // 타임라인 확대 배율 (화면 너비의 3배)
    private let timelineScale: CGFloat = 3.0

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator

        let containerView = UIView()
        containerView.backgroundColor = .clear
        scrollView.addSubview(containerView)
        context.coordinator.containerView = containerView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let containerView = context.coordinator.containerView else { return }

        let screenWidth = scrollView.bounds.width
        let timelineWidth = screenWidth * timelineScale
        let playheadPosition = duration > 0 ? (currentTime / duration) * timelineWidth : 0

        // Container 크기 설정
        containerView.frame = CGRect(x: 0, y: 0, width: timelineWidth, height: scrollView.bounds.height)
        scrollView.contentSize = CGSize(width: timelineWidth, height: scrollView.bounds.height)

        // Timeline trimmer view 업데이트 (먼저)
        if context.coordinator.timelineHostingController == nil {
            let hostingController = UIHostingController(rootView:
                AnyView(
                    VideoTimelineTrimmer(
                        videoAsset: videoAsset,
                        duration: duration,
                        trimStartTime: trimStartTime,
                        trimEndTime: trimEndTime,
                        onTrimStartChanged: onTrimStartChanged,
                        onTrimEndChanged: onTrimEndChanged
                    )
                    .frame(width: timelineWidth, height: 60)
                )
            )
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = CGRect(x: 0, y: 0, width: timelineWidth, height: 60)
            containerView.addSubview(hostingController.view)
            context.coordinator.timelineHostingController = hostingController
            context.coordinator.timelineView = hostingController.view
        } else {
            // Timeline이 이미 존재하면 rootView 업데이트
            context.coordinator.timelineHostingController?.rootView = AnyView(
                VideoTimelineTrimmer(
                    videoAsset: videoAsset,
                    duration: duration,
                    trimStartTime: trimStartTime,
                    trimEndTime: trimEndTime,
                    onTrimStartChanged: onTrimStartChanged,
                    onTrimEndChanged: onTrimEndChanged
                )
                .frame(width: timelineWidth, height: 60)
            )

            // Frame 업데이트
            context.coordinator.timelineView?.frame = CGRect(x: 0, y: 0, width: timelineWidth, height: 60)
        }

        // Playhead view 업데이트 (나중에 - 항상 최상위에 표시)
        if context.coordinator.playheadView == nil {
            let playheadView = PlayheadUIView(frame: CGRect(x: 0, y: 0, width: 12, height: scrollView.bounds.height))
            playheadView.layer.zPosition = 1000
            containerView.addSubview(playheadView)
            context.coordinator.playheadView = playheadView
            playheadView.setNeedsDisplay()
        }

        if let playheadView = context.coordinator.playheadView {
            let oldHeight = playheadView.frame.size.height
            let newHeight = scrollView.bounds.height

            // 높이가 변경되면 다시 그리기
            if oldHeight != newHeight {
                playheadView.frame.size.height = newHeight
                playheadView.setNeedsDisplay()
            }

            // playhead를 항상 맨 앞으로
            containerView.bringSubviewToFront(playheadView)
            playheadView.layer.zPosition = 1000

            UIView.animate(withDuration: 0.1, delay: 0, options: [.curveLinear], animations: {
                playheadView.frame.origin.x = playheadPosition - 6
            })
        }

        // 스크롤 자동 조정 (playhead가 화면 중앙에 오도록)
        if !context.coordinator.isUserScrolling {
            let targetOffsetX = playheadPosition - screenWidth / 2
            let maxOffsetX = max(0, timelineWidth - screenWidth)
            let clampedOffsetX = max(0, min(targetOffsetX, maxOffsetX))

            UIView.animate(withDuration: 0.1, delay: 0, options: [.curveLinear], animations: {
                scrollView.contentOffset.x = clampedOffsetX
            })
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var containerView: UIView?
        var playheadView: PlayheadUIView?
        var timelineView: UIView?
        var timelineHostingController: UIHostingController<AnyView>?
        var isUserScrolling = false

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserScrolling = true
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isUserScrolling = false
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserScrolling = false
        }
    }
}

// MARK: - Playhead UIView (네이티브)
private class PlayheadUIView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // 검정색으로 설정
        UIColor.black.setFill()

        // 상단 삼각형 그리기 (▼)
        let trianglePath = UIBezierPath()
        trianglePath.move(to: CGPoint(x: rect.midX, y: 8))  // 아래 꼭지점
        trianglePath.addLine(to: CGPoint(x: 0, y: 0))       // 왼쪽 위
        trianglePath.addLine(to: CGPoint(x: rect.width, y: 0))  // 오른쪽 위
        trianglePath.close()
        trianglePath.fill()

        // 세로선 그리기
        let lineRect = CGRect(x: rect.midX - 1, y: 8, width: 2, height: rect.height - 8)
        UIBezierPath(rect: lineRect).fill()
    }
}

// MARK: - Playhead View (SwiftUI - 사용 안 함)
private struct PlayheadView: View {
    var body: some View {
        VStack(spacing: 0) {
            // 상단 삼각형 (재생 헤드)
            Triangle()
                .fill(Color.black)
                .frame(width: 12, height: 8)

            // 세로선
            Rectangle()
                .fill(Color.black)
                .frame(width: 2)
        }
    }
}

// MARK: - Triangle Shape
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Filter Selection View
private struct FilterSelectionView: View {
    let selectedFilter: VideoFilter?
    let onFilterSelected: (VideoFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppPadding.medium) {
                ForEach(VideoFilter.allCases, id: \.self) { filter in
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
    let filter: VideoFilter
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
    let preProcessedVideoURL: URL?  // AnimeGAN 등 전처리된 비디오
    let isPlaying: Bool
    let seekTrigger: EditVideoFeature.SeekDirection?
    let selectedFilter: VideoFilter?
    let onTimeUpdate: (Double) -> Void
    let onDurationUpdate: (Double) -> Void
    let onSeekCompleted: () -> Void
    let onFilterApplied: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let preProcessedVideoURL = preProcessedVideoURL {
            // 전처리된 비디오가 있으면 그것을 로드
            context.coordinator.loadVideo(from: preProcessedVideoURL, in: view)
        } else {
            // 없으면 원본 PHAsset 로드
            context.coordinator.loadVideo(for: asset, in: view)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 전처리된 비디오가 변경되면 다시 로드
        if context.coordinator.currentPreProcessedURL != preProcessedVideoURL {
            if let preProcessedVideoURL = preProcessedVideoURL {
                // 전처리된 비디오 로드
                context.coordinator.loadVideo(from: preProcessedVideoURL, in: uiView)
                // 전처리된 비디오에는 필터가 이미 구워져 있으므로 lastAppliedFilter 설정
                context.coordinator.lastAppliedFilter = selectedFilter
            } else {
                // 원본 비디오 로드
                context.coordinator.loadVideo(for: asset, in: uiView)
                // 원본 비디오는 필터 적용 필요하므로 초기화
                context.coordinator.lastAppliedFilter = nil
            }
        }

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

        // 전처리된 비디오를 사용하는 경우 필터는 이미 적용되어 있으므로 스킵
        if preProcessedVideoURL == nil {
            // 원본 비디오 재생 중 - 실시간 필터 적용
            context.coordinator.updateFilter(selectedFilter, onComplete: onFilterApplied)
        }
        // 전처리된 비디오는 이미 필터가 구워져 있으므로 아무것도 하지 않음
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
        var lastAppliedFilter: VideoFilter?
        var currentPreProcessedURL: URL?  // 현재 로드된 전처리 비디오 URL
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
            currentPreProcessedURL = nil  // PHAsset 로드 시 전처리 URL 초기화

            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
                guard let self, let avAsset else { return }

                DispatchQueue.main.async {
                    self.setupPlayer(with: avAsset, in: view)
                }
            }
        }

        func loadVideo(from url: URL, in view: UIView) {
            currentPreProcessedURL = url  // 전처리 URL 저장

            let avAsset = AVAsset(url: url)
            DispatchQueue.main.async { [weak self] in
                self?.setupPlayer(with: avAsset, in: view)
            }
        }

        private func setupPlayer(with avAsset: AVAsset, in view: UIView) {
            // 기존 플레이어 정리
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            player?.pause()
            playerLayer?.removeFromSuperlayer()

            // 새 플레이어 설정
            currentAVAsset = avAsset
            let playerItem = AVPlayerItem(asset: avAsset)

            player = AVPlayer(playerItem: playerItem)
            playerLayer = AVPlayerLayer(player: player)
            playerLayer?.frame = view.bounds
            playerLayer?.videoGravity = .resizeAspect

            if let playerLayer = playerLayer {
                view.layer.addSublayer(playerLayer)
            }

            // Duration 업데이트
            Task { [weak self] in
                if let duration = try? await avAsset.load(.duration) {
                    let durationSeconds = duration.seconds
                    if durationSeconds.isFinite {
                        await MainActor.run {
                            self?.onDurationUpdate(durationSeconds)
                        }
                    }
                }
            }

            // 시간 업데이트 observer 추가
            let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
            timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                let currentTime = time.seconds
                if currentTime.isFinite {
                    self?.onTimeUpdate(currentTime)
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

        func updateFilter(_ filterType: VideoFilter?, onComplete: @escaping () -> Void) {
            // AnimeGAN 필터는 실시간 적용하지 않음 (전처리 방식 사용)
            if filterType == .animeGANHayao {
                // onComplete를 호출하지 않아서 indicator가 계속 표시되도록 함
                // 전처리가 완료되면 preProcessCompleted에서 indicator가 사라짐
                return
            }

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
                // VideoFilterManager를 사용하여 필터 적용
                let videoComposition = await VideoFilterManager.createVideoComposition(
                    for: avAsset,
                    filter: filterType
                )

                // 메인 스레드에서 videoComposition 적용
                await MainActor.run {
                    playerItem.videoComposition = videoComposition
                    // 약간의 딜레이 후 완료 콜백 호출 (필터 적용이 안정화되도록)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }
            }
        }

        deinit {
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            player?.pause()
        }
    }
}
