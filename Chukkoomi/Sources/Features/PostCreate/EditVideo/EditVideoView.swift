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
                // 커스텀 비디오 플레이어
                CustomVideoPlayerView(
                    asset: viewStore.videoAsset,
                    preProcessedVideoURL: viewStore.preProcessedVideoURL,
                    isPlaying: viewStore.isPlaying,
                    seekTrigger: viewStore.seekTrigger,
                    seekTarget: viewStore.seekTarget,
                    selectedFilter: viewStore.editState.selectedFilter,
                    backgroundMusics: viewStore.editState.backgroundMusics,
                    onTimeUpdate: { time in viewStore.send(.updateCurrentTime(time)) },
                    onDurationUpdate: { duration in viewStore.send(.updateDuration(duration)) },
                    onVideoSizeUpdate: { size in viewStore.send(.updateVideoDisplaySize(size)) },
                    onSeekCompleted: { viewStore.send(.seekCompleted) },
                    onFilterApplied: { viewStore.send(.filterApplied) },
                    onPlaybackEnded: { viewStore.send(.playbackEnded) }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .overlay {
                    // 자막 오버레이
                    SubtitleOverlayView(
                        currentTime: viewStore.currentTime,
                        subtitles: viewStore.editState.subtitles,
                        videoDisplaySize: viewStore.videoDisplaySize
                    )
                }
                .overlay {
                    if viewStore.isApplyingFilter {
                        FilterApplyingOverlayView()
                    }
                }
                
                // 편집 영역
                ScrollView {
                    HStack(alignment: .top, spacing: 16) {
                        EditControlsView(viewStore: viewStore)
                            .padding(.leading, AppPadding.large)
                        
                        VStack(spacing: 16) {
                            // 시간 눈금자 + 가로 스크롤 가능한 타임라인 편집 영역 + 자막 영역 (통합)
                            VideoTimelineEditor(
                                videoAsset: viewStore.videoAsset,
                                duration: viewStore.duration,
                                currentTime: viewStore.currentTime,
                                seekTarget: viewStore.seekTarget,
                                trimStartTime: viewStore.editState.trimStartTime,
                                trimEndTime: viewStore.editState.trimEndTime,
                                subtitles: viewStore.editState.subtitles,
                                backgroundMusics: viewStore.editState.backgroundMusics,
                                isPlaying: viewStore.isPlaying,
                                onTrimStartChanged: { time in
                                    viewStore.send(.updateTrimStartTime(time))
                                },
                                onTrimEndChanged: { time in
                                    viewStore.send(.updateTrimEndTime(time))
                                },
                                onSeek: { time in
                                    viewStore.send(.seekToTime(time))
                                },
                                onRemoveSubtitle: { id in
                                    viewStore.send(.removeSubtitle(id))
                                },
                                onUpdateSubtitleStartTime: { id, time in
                                    viewStore.send(.updateSubtitleStartTime(id, time))
                                },
                                onUpdateSubtitleEndTime: { id, time in
                                    viewStore.send(.updateSubtitleEndTime(id, time))
                                },
                                onEditSubtitle: { id in
                                    viewStore.send(.editSubtitle(id))
                                },
                                onRemoveBackgroundMusic: { id in
                                    viewStore.send(.removeBackgroundMusic(id))
                                },
                                onUpdateBackgroundMusicStartTime: { id, time in
                                    viewStore.send(.updateBackgroundMusicStartTime(id, time))
                                },
                                onUpdateBackgroundMusicEndTime: { id, time in
                                    viewStore.send(.updateBackgroundMusicEndTime(id, time))
                                }
                            )
                            .frame(height: 20 + 16 + 80 + 16 + 80 + 16 + 80) // 눈금자(20) + 간격(16) + 타임라인(80) + 간격(16) + 자막(80) + 간격(16) + 배경음악(80)
                            
                            // 필터 선택
                            FilterSelectionView(
                                selectedFilter: viewStore.editState.selectedFilter,
                                purchasedFilterTypes: viewStore.purchasedFilterTypes,
                                onFilterSelected: { filter in
                                    viewStore.send(.filterSelected(filter))
                                }
                            )
                        }
                    }
                    .padding(.top, AppPadding.large)
                    
                    Spacer()
                }
                
            }
            .ignoresSafeArea(.keyboard)
            .navigationTitle("영상 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationBarBackButtonHidden(viewStore.isExporting || viewStore.isShowingSubtitleInput || viewStore.isShowingMusicSelection)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewStore.send(.completeButtonTapped)
                    } label: {
                        Text("완료")
                            .foregroundStyle(.black)
                    }
                    .disabled(viewStore.isExporting || viewStore.isShowingSubtitleInput || viewStore.isShowingMusicSelection)
                }
            }
            .overlay {
                if viewStore.isExporting {
                    ExportingOverlayView(progress: viewStore.exportProgress)
                        .ignoresSafeArea()
                }
            }
            .overlay {
                if viewStore.isShowingSubtitleInput {
                    SubtitleInputOverlayView(
                        text: viewStore.binding(
                            get: \.subtitleInputText,
                            send: { .updateSubtitleInputText($0) }
                        ),
                        errorMessage: viewStore.subtitleInputValidationError,
                        onConfirm: { viewStore.send(.confirmSubtitleInput) },
                        onCancel: { viewStore.send(.cancelSubtitleInput) }
                    )
                    .ignoresSafeArea()
                }
            }
            .overlay {
                if viewStore.isShowingMusicSelection {
                    MusicSelectionOverlayView(
                        onSelectMusic: { url in
                            viewStore.send(.selectMusic(url))
                        },
                        onCancel: { viewStore.send(.cancelMusicSelection) }
                    )
                    .ignoresSafeArea()
                }
            }
            .alert(store: store.scope(state: \.$alert, action: \.alert))
            .onAppear {
                viewStore.send(.onAppear)
            }
            .overlay {
                if viewStore.isPurchaseModalPresented {
                    PurchaseModalView(viewStore: viewStore)
                }
            }
            .overlay {
                // 구매하기 버튼 누르면 그때만 WebView 표시
                if viewStore.isProcessingPayment {
                    ZStack {
                        Color.black.opacity(0.9)
                            .ignoresSafeArea()

                        IamportWebView(webView: Binding(
                            get: { viewStore.webView },
                            set: { webView in
                                if let webView {
                                    viewStore.send(.webViewCreated(webView))
                                }
                            }
                        ))
                        .background(Color.white)
                    }
                }
            }
        }
    }
}

// MARK: - Custom Video Player
private struct CustomVideoPlayerView: UIViewRepresentable {
    let asset: PHAsset
    let preProcessedVideoURL: URL?  // AnimeGAN 등 전처리된 비디오
    let isPlaying: Bool
    let seekTrigger: EditVideoFeature.SeekDirection?
    let seekTarget: Double?
    let selectedFilter: VideoFilter?
    let backgroundMusics: [EditVideoFeature.BackgroundMusic]
    let onTimeUpdate: (Double) -> Void
    let onDurationUpdate: (Double) -> Void
    let onVideoSizeUpdate: (CGSize) -> Void
    let onSeekCompleted: () -> Void
    let onFilterApplied: () -> Void
    let onPlaybackEnded: () -> Void
    
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

        // 배경음악 설정
        context.coordinator.updateBackgroundMusics(backgroundMusics)

        // 재생/일시정지 처리
        if isPlaying {
            context.coordinator.play()
        } else {
            context.coordinator.pause()
        }

        // Seek to time 처리
        if let seekTarget = seekTarget {
            context.coordinator.seekToTime(seekTarget)
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
            onDurationUpdate: onDurationUpdate,
            onVideoSizeUpdate: onVideoSizeUpdate,
            onPlaybackEnded: onPlaybackEnded
        )
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var timeObserver: Any?
        var boundaryObserver: Any?
        var currentAVAsset: AVAsset?
        var currentPHAsset: PHAsset?  // 현재 로드된 PHAsset 저장
        var lastAppliedFilter: VideoFilter?
        var currentPreProcessedURL: URL?  // 현재 로드된 전처리 비디오 URL
        var containerView: UIView?  // 비디오 크기 계산용 컨테이너

        // 배경음악 관련
        var audioPlayers: [UUID: AVPlayer] = [:]  // 배경음악 ID별 플레이어
        var musicDurations: [UUID: Double] = [:]  // 배경음악 ID별 duration 캐시
        var currentBackgroundMusics: [EditVideoFeature.BackgroundMusic] = []
        var currentVideoTime: Double = 0.0

        let onTimeUpdate: (Double) -> Void
        let onDurationUpdate: (Double) -> Void
        let onVideoSizeUpdate: (CGSize) -> Void
        let onPlaybackEnded: () -> Void

        init(
            onTimeUpdate: @escaping (Double) -> Void,
            onDurationUpdate: @escaping (Double) -> Void,
            onVideoSizeUpdate: @escaping (CGSize) -> Void,
            onPlaybackEnded: @escaping () -> Void
        ) {
            self.onTimeUpdate = onTimeUpdate
            self.onDurationUpdate = onDurationUpdate
            self.onVideoSizeUpdate = onVideoSizeUpdate
            self.onPlaybackEnded = onPlaybackEnded
        }
        
        func loadVideo(for asset: PHAsset, in view: UIView) {
            currentPreProcessedURL = nil  // PHAsset 로드 시 전처리 URL 초기화
            currentPHAsset = asset  // PHAsset 저장
            containerView = view  // 컨테이너 저장

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
            containerView = view  // 컨테이너 저장
            // 전처리 영상은 URL에서 로드되므로 PHAsset은 nil (원본 PHAsset 정보는 유지됨)

            let avAsset = AVAsset(url: url)
            DispatchQueue.main.async { [weak self] in
                self?.setupPlayer(with: avAsset, in: view)
            }
        }
        
        private func setupPlayer(with avAsset: AVAsset, in view: UIView) {
            // 기존 플레이어 정리
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            if let boundaryObserver = boundaryObserver {
                player?.removeTimeObserver(boundaryObserver)
                self.boundaryObserver = nil
            }
            player?.pause()
            playerLayer?.removeFromSuperlayer()

            // 새 플레이어 설정
            currentAVAsset = avAsset
            let playerItem = AVPlayerItem(asset: avAsset)

            player = AVPlayer(playerItem: playerItem)
            player?.actionAtItemEnd = .pause
            playerLayer = AVPlayerLayer(player: player)
            playerLayer?.frame = view.bounds
            playerLayer?.videoGravity = .resizeAspect

            if let playerLayer = playerLayer {
                view.layer.addSublayer(playerLayer)
            }

            // Duration, 비디오 크기 업데이트 및 경계 옵저버 등록
            Task { [weak self] in
                guard let self else { return }

                // Duration 업데이트
                if let duration = try? await avAsset.load(.duration) {
                    let durationSeconds = duration.seconds
                    if durationSeconds.isFinite {
                        await MainActor.run {
                            self.onDurationUpdate(durationSeconds)
                            self.installBoundaryObserver(at: duration)
                        }
                    }
                }

                // 비디오 크기 계산 및 업데이트
                if let videoTrack = try? await avAsset.loadTracks(withMediaType: .video).first,
                   let naturalSize = try? await videoTrack.load(.naturalSize),
                   let preferredTransform = try? await videoTrack.load(.preferredTransform),
                   let containerView = self.containerView {

                    // preferredTransform 적용한 실제 비디오 크기
                    let isRotated = preferredTransform.b != 0 || preferredTransform.c != 0
                    let videoSize = isRotated
                        ? CGSize(width: naturalSize.height, height: naturalSize.width)
                        : naturalSize

                    // 컨테이너 크기 내에서 aspect-fit으로 표시되는 실제 크기 계산
                    let containerSize = await containerView.bounds.size
                    let displaySize = self.calculateAspectFitSize(
                        videoSize: videoSize,
                        containerSize: containerSize
                    )

                    await MainActor.run {
                        self.onVideoSizeUpdate(displaySize)
                    }
                }
            }
            
            // 시간 업데이트 observer 추가
            let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
            timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                guard let self else { return }
                let currentTime = time.seconds
                // 방어적으로 NaN/Infinite 방지 및 duration 클램프
                if currentTime.isFinite {
                    self.currentVideoTime = currentTime
                    if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite {
                        self.onTimeUpdate(min(currentTime, duration))
                    } else {
                        self.onTimeUpdate(currentTime)
                    }

                    // 배경음악 동기화
                    self.syncBackgroundMusic()
                }
            }
        }
        
        private func installBoundaryObserver(at duration: CMTime) {
            guard let player else { return }
            
            // 끝 지점 바로 직전(약간 앞)에도 한 번, 끝 지점에도 한 번 경계 설정
            // 끝 지점만 등록하면 일부 상황에서 정밀도 이슈로 콜백이 건너뛰는 것을 방지
            let epsilon = CMTime(seconds: 0.01, preferredTimescale: duration.timescale)
            let almostEnd = CMTimeSubtract(duration, epsilon)
            let times: [NSValue] = [NSValue(time: almostEnd), NSValue(time: duration)]
            
            boundaryObserver = player.addBoundaryTimeObserver(forTimes: times, queue: .main) { [weak self] in
                guard let self else { return }
                self.player?.pause()
                
                // 시간을 끝으로 고정
                if let end = self.player?.currentItem?.duration.seconds, end.isFinite {
                    self.onTimeUpdate(end)
                }
                self.onPlaybackEnded()
            }
        }
        
        func play() {
            player?.play()
            // 배경음악도 동기화하여 재생
            syncBackgroundMusic()
        }

        func pause() {
            player?.pause()
            audioPlayers.values.forEach { $0.pause() }
        }

        func seekToTime(_ time: Double) {
            guard let player = player else { return }
            let targetTime = CMTime(seconds: time, preferredTimescale: 600)
            currentVideoTime = time

            // 즉시 이동하도록 completion handler 사용
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
                if completed {
                    // seek가 완료되면 즉시 시간 업데이트
                    DispatchQueue.main.async {
                        self?.onTimeUpdate(time)
                        // 배경음악도 동기화
                        self?.syncBackgroundMusic()
                    }
                }
            }
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
                // PHAsset으로부터 세로 영상 여부 판단
                let isPortraitFromPHAsset: Bool
                if let phAsset = currentPHAsset {
                    isPortraitFromPHAsset = phAsset.pixelWidth < phAsset.pixelHeight
                } else {
                    // PHAsset이 없으면 (전처리 영상인 경우) AVAsset의 naturalSize로 판단
                    if let videoTrack = try? await avAsset.loadTracks(withMediaType: .video).first,
                       let naturalSize = try? await videoTrack.load(.naturalSize) {
                        isPortraitFromPHAsset = naturalSize.width < naturalSize.height
                    } else {
                        isPortraitFromPHAsset = false
                    }
                }
                
                // VideoFilterManager를 사용하여 필터 적용
                let videoComposition = await VideoFilterManager.createVideoComposition(
                    for: avAsset,
                    filter: filterType,
                    isPortraitFromPHAsset: isPortraitFromPHAsset
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
        
        private func calculateAspectFitSize(videoSize: CGSize, containerSize: CGSize) -> CGSize {
            guard videoSize.width > 0 && videoSize.height > 0 else {
                return containerSize
            }

            let videoAspect = videoSize.width / videoSize.height
            let containerAspect = containerSize.width / containerSize.height

            if videoAspect > containerAspect {
                // 비디오가 더 넓음 - 너비에 맞춤
                return CGSize(
                    width: containerSize.width,
                    height: containerSize.width / videoAspect
                )
            } else {
                // 비디오가 더 높음 - 높이에 맞춤
                return CGSize(
                    width: containerSize.height * videoAspect,
                    height: containerSize.height
                )
            }
        }

        func updateBackgroundMusics(_ backgroundMusics: [EditVideoFeature.BackgroundMusic]) {
            // 현재 배경음악 ID 목록
            let currentMusicIDs = Set(backgroundMusics.map { $0.id })

            // 1. 삭제된 배경음악의 플레이어 및 duration 캐시 제거
            let oldMusicIDs = Set(audioPlayers.keys)
            let removedMusicIDs = oldMusicIDs.subtracting(currentMusicIDs)
            for musicID in removedMusicIDs {
                audioPlayers[musicID]?.pause()
                audioPlayers.removeValue(forKey: musicID)
                musicDurations.removeValue(forKey: musicID)
            }

            // 2. 각 배경음악에 대해 플레이어 생성 또는 업데이트
            for music in backgroundMusics {
                if let existingPlayer = audioPlayers[music.id] {
                    // 기존 플레이어 업데이트 (볼륨만)
                    existingPlayer.volume = music.volume
                } else {
                    // 새 플레이어 생성
                    let audioAsset = AVAsset(url: music.musicURL)
                    let playerItem = AVPlayerItem(asset: audioAsset)
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    newPlayer.volume = music.volume
                    audioPlayers[music.id] = newPlayer

                    // duration 비동기 로드 및 캐시
                    let musicID = music.id
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let duration = try? await audioAsset.load(.duration) {
                            self.musicDurations[musicID] = duration.seconds
                        }
                    }
                }
            }

            // 현재 배경음악 목록 업데이트
            currentBackgroundMusics = backgroundMusics

            // 현재 비디오 시간에 맞춰 동기화
            syncBackgroundMusic()
        }

        private func syncBackgroundMusic() {
            let videoTime = currentVideoTime

            // 각 배경음악에 대해 동기화
            for music in currentBackgroundMusics {
                guard let audioPlayer = audioPlayers[music.id] else { continue }

                // 배경음악 재생 범위 내에 있는지 확인
                if videoTime >= music.startTime && videoTime <= music.endTime {
                    // 음악 내에서의 상대 시간 계산 (루프를 위해)
                    let relativeTime = videoTime - music.startTime

                    // 캐시된 duration 사용
                    if let audioDuration = musicDurations[music.id],
                       audioDuration.isFinite {
                        // 음악 길이로 나눈 나머지로 루프
                        let loopedTime = relativeTime.truncatingRemainder(dividingBy: audioDuration)
                        let targetTime = CMTime(seconds: loopedTime, preferredTimescale: 600)

                        // 현재 재생 중인 시간과 목표 시간의 차이가 크면 seek
                        if let currentTime = audioPlayer.currentItem?.currentTime().seconds,
                           abs(currentTime - loopedTime) > 0.2 {
                            audioPlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                        }

                        // 비디오가 재생 중이면 배경음악도 재생
                        if player?.rate ?? 0 > 0 {
                            if audioPlayer.rate == 0 {
                                audioPlayer.play()
                            }
                        } else {
                            audioPlayer.pause()
                        }
                    }
                } else {
                    // 배경음악 범위 밖이면 일시정지
                    audioPlayer.pause()
                }
            }
        }

        deinit {
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            if let boundaryObserver = boundaryObserver {
                player?.removeTimeObserver(boundaryObserver)
            }
            player?.pause()
            audioPlayers.values.forEach { $0.pause() }
        }
    }
}

// MARK: - Subtitle Overlay View
private struct SubtitleOverlayView: View {
    let currentTime: Double
    let subtitles: [EditVideoFeature.Subtitle]
    let videoDisplaySize: CGSize

    var body: some View {
        GeometryReader { geometry in
            // 현재 시간에 표시할 자막 찾기
            if let currentSubtitle = subtitles.first(where: { subtitle in
                currentTime >= subtitle.startTime && currentTime <= subtitle.endTime
            }), videoDisplaySize.width > 0 && videoDisplaySize.height > 0 {

                // 실제 영상과 동일한 비율로 자막 크기 계산
                // VideoCompositor와 동일하게: width * 0.06
                let fontSize = videoDisplaySize.width * 0.06
                let outlineOffset: CGFloat = 1.5

                // 컨테이너 내에서 비디오가 표시되는 영역 계산 (중앙 정렬)
                let containerSize = geometry.size
                let videoOriginX = (containerSize.width - videoDisplaySize.width) / 2
                let videoOriginY = (containerSize.height - videoDisplaySize.height) / 2

                ZStack {
                    // 검정 테두리 (여러 겹)
                    ForEach(0..<8) { i in
                        Text(currentSubtitle.text)
                            .font(.system(size: fontSize, weight: .bold))
                            .foregroundStyle(.black.opacity(0.6))
                            .offset(
                                x: CGFloat(i % 3 - 1) * outlineOffset,
                                y: CGFloat(i / 3 - 1) * outlineOffset
                            )
                    }

                    // 흰색 텍스트
                    Text(currentSubtitle.text)
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: videoDisplaySize.width)
                .position(
                    x: videoOriginX + videoDisplaySize.width / 2,
                    y: videoOriginY + videoDisplaySize.height - videoDisplaySize.height * 0.05 - fontSize / 2
                )
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

// MARK: - Edit Controls View
private struct EditControlsView: View {
    let viewStore: ViewStoreOf<EditVideoFeature>
    
    var body: some View {
        VStack(spacing: 0) {
            // 재생 버튼
            VideoControlsView(
                isPlaying: viewStore.isPlaying,
                onPlayPause: { viewStore.send(.playPauseButtonTapped) }
            )
            .frame(width: 32, height: 32)
            .offset(y: -6)
            
            // 자르기
            EditGuideView(editType: .trim)
                .frame(width: 44, height: 36)
                .padding(.top, 30)
            
            // 자막 추가 버튼
            Button {
                viewStore.send(.addSubtitle)
            } label: {
                EditGuideView(editType: .subtitle)
            }
            .frame(width: 44, height: 36)
            .padding(.top, 60)

            // 배경음악 추가 버튼
            Button {
                viewStore.send(.showMusicSelection)
            } label: {
                EditGuideView(editType: .music)
            }
            .frame(width: 44, height: 36)
            .padding(.top, 60)

            // 필터
            EditGuideView(editType: .filter)
                .frame(width: 44, height: 36)
                .padding(.top, 60)
        }
    }
}

// MARK: - Edit Guide View
private struct EditGuideView: View {
    let editType: EditType

    var body: some View {
        VStack(spacing: 4) {
            icon

            HStack(spacing: 2) {
                Text(editType.rawValue)
                    .multilineTextAlignment(.center)
                    .font(.appCaption)

                if editType == .subtitle || editType == .music {
                    AppIcon.plusCircle
                        .font(.system(size: 14))
                }
            }
        }
        .foregroundStyle(.black)
    }

    enum EditType: String {
        case trim = "자르기"
        case subtitle = "자막"
        case music = "음악"
        case filter = "필터"
    }

    var icon: some View {
        switch editType {
        case .trim:
            AppIcon.trim
                .font(.system(size: 20))
        case .subtitle:
            AppIcon.subtitle
                .font(.system(size: 24))
        case .music:
            AppIcon.music
                .font(.system(size: 24))
        case .filter:
            AppIcon.filter
                .font(.system(size: 24))
        }
    }
}

// MARK: - Video Controls View
private struct VideoControlsView: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    
    var body: some View {
        // 재생/일시정지 버튼
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
    }
}

// MARK: - Video Timeline Editor
private struct VideoTimelineEditor: UIViewRepresentable {
    let videoAsset: PHAsset
    let duration: Double
    let currentTime: Double
    let seekTarget: Double?
    let trimStartTime: Double
    let trimEndTime: Double
    let subtitles: [EditVideoFeature.Subtitle]
    let backgroundMusics: [EditVideoFeature.BackgroundMusic]
    let isPlaying: Bool
    let onTrimStartChanged: (Double) -> Void
    let onTrimEndChanged: (Double) -> Void
    let onSeek: (Double) -> Void
    let onRemoveSubtitle: (UUID) -> Void
    let onUpdateSubtitleStartTime: (UUID, Double) -> Void
    let onUpdateSubtitleEndTime: (UUID, Double) -> Void
    let onEditSubtitle: (UUID) -> Void
    let onRemoveBackgroundMusic: (UUID) -> Void
    let onUpdateBackgroundMusicStartTime: (UUID, Double) -> Void
    let onUpdateBackgroundMusicEndTime: (UUID, Double) -> Void
    
    // 1초당 픽셀 수
    private let pixelsPerSecond: CGFloat = 50

    // 눈금자와 썸네일 타임라인 사이 간격 (삼각형이 들어갈 공간)
    private let gapBetweenRulerAndTimeline: CGFloat = 16

    // 시간 Font
    private let timeFont = UIFont.systemFont(ofSize: 16, weight: .regular)

    // 타임라인 좌우 패딩
    private let timelinePadding: CGFloat = 16
    
    // 타임라인 높이
    private let trimmerHeight: CGFloat = 80
    // 자막 영역 높이
    private let subtitleHeight: CGFloat = 80
    // 타임라인과 자막 사이 간격
    private let gapBetweenTrimmerAndSubtitle: CGFloat = 16
    // 배경음악 영역 높이
    private let backgroundMusicHeight: CGFloat = 80
    // 자막과 배경음악 사이 간격
    private let gapBetweenSubtitleAndMusic: CGFloat = 16
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator
        
        // contentInset 제거 (타임라인에 이미 패딩 포함)
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        
        let containerView = UIView()
        containerView.backgroundColor = .clear
        scrollView.addSubview(containerView)
        context.coordinator.containerView = containerView
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let containerView = context.coordinator.containerView else { return }

        // ScrollView 참조 저장
        context.coordinator.scrollView = scrollView

        let screenWidth = scrollView.bounds.width
        
        // 안전한 width/height 계산 (음수/비유한 방지)
        let safeDuration = duration.isFinite && duration >= 0 ? duration : 0
        let timelineWidth = max(0, CGFloat(safeDuration) * pixelsPerSecond + timelinePadding * 2)
        
        let totalHeight = scrollView.bounds.height
        let rulerHeight: CGFloat = 20
        // 타임라인 시작 Y는 눈금자 아래 gap만큼 띄움
        let timelineOriginY = rulerHeight + gapBetweenRulerAndTimeline
        let timelineHeight = trimmerHeight

        // Coordinator에 저장
        context.coordinator.timelineOriginY = timelineOriginY
        context.coordinator.timelineHeight = timelineHeight
        
        // 자막 영역 Y 위치 (타임라인 아래 + 간격)
        let subtitleOriginY = timelineOriginY + timelineHeight + gapBetweenTrimmerAndSubtitle

        // 배경음악 영역 Y 위치 (자막 아래 + 간격)
        let backgroundMusicOriginY = subtitleOriginY + subtitleHeight + gapBetweenSubtitleAndMusic
        
        // 현재 재생 헤드 위치 (패딩 고려)
        let playheadPosition = (safeDuration > 0)
        ? timelinePadding + (currentTime / safeDuration) * (timelineWidth - timelinePadding * 2)
        : timelinePadding
        
        // Container 크기 설정 (핸들 영역 포함)
        containerView.frame = CGRect(x: 0, y: 0, width: timelineWidth, height: totalHeight)
        scrollView.contentSize = CGSize(width: timelineWidth, height: totalHeight)
        
        // 시간 표시 컨테이너 뷰 (눈금자 + 현재 시간 라벨)
        if context.coordinator.timeDisplayContainer == nil {
            let timeContainer = UIView()
            timeContainer.backgroundColor = .clear
            containerView.addSubview(timeContainer)
            context.coordinator.timeDisplayContainer = timeContainer
        }
        
        if let timeContainer = context.coordinator.timeDisplayContainer {
            // 눈금자 전체 너비 (핸들이 안쪽에 있으므로 타임라인 너비와 동일)
            let rulerTotalWidth = timelineWidth
            
            // 컨테이너를 왼쪽 끝에서 시작
            timeContainer.frame = CGRect(x: 0, y: 0, width: rulerTotalWidth, height: rulerHeight)
            
            // 시간 눈금자 view 업데이트
            if context.coordinator.rulerView == nil {
                let rulerView = TimeRulerView(frame: CGRect(x: 0, y: 0, width: rulerTotalWidth, height: rulerHeight))
                rulerView.duration = safeDuration
                rulerView.pixelsPerSecond = pixelsPerSecond
                rulerView.padding = timelinePadding
                rulerView.backgroundColor = .clear
                rulerView.onSeek = onSeek
                timeContainer.addSubview(rulerView)
                context.coordinator.rulerView = rulerView
            } else {
                context.coordinator.rulerView?.frame = CGRect(x: 0, y: 0, width: rulerTotalWidth, height: rulerHeight)
                context.coordinator.rulerView?.duration = safeDuration
                context.coordinator.rulerView?.pixelsPerSecond = pixelsPerSecond
                context.coordinator.rulerView?.padding = timelinePadding
                context.coordinator.rulerView?.onSeek = onSeek
                context.coordinator.rulerView?.setNeedsDisplay()
            }
        }
        
        // VideoTimelineTrimmer 컨테이너 뷰 (썸네일 영역)
        if context.coordinator.trimmerContainer == nil {
            let trimmerContainer = UIView()
            trimmerContainer.backgroundColor = .clear
            containerView.addSubview(trimmerContainer)
            context.coordinator.trimmerContainer = trimmerContainer

            // 로딩 indicator는 ThumbnailsView의 로딩 상태에 따라 동적으로 생성됨
        }
        
        if let trimmerContainer = context.coordinator.trimmerContainer {
            // 패딩만큼 오른쪽으로 이동
            trimmerContainer.frame = CGRect(x: timelinePadding, y: timelineOriginY, width: timelineWidth - timelinePadding * 2, height: timelineHeight)
            
            // Timeline trimmer view 업데이트
            let contentWidth = timelineWidth - timelinePadding * 2
            if context.coordinator.timelineHostingController == nil {
                let hostingController = UIHostingController(rootView:
                                                                AnyView(
                                                                    VideoTimelineTrimmer(
                                                                        videoAsset: videoAsset,
                                                                        duration: safeDuration,
                                                                        trimStartTime: trimStartTime,
                                                                        trimEndTime: trimEndTime,
                                                                        onTrimStartChanged: onTrimStartChanged,
                                                                        onTrimEndChanged: onTrimEndChanged,
                                                                        onLoadingChanged: { isLoading in
                                                                            context.coordinator.updateLoadingIndicator(isLoading: isLoading)
                                                                        }
                                                                    )
                                                                    .frame(width: contentWidth, height: timelineHeight)
                                                                )
                )
                hostingController.view.backgroundColor = .clear
                hostingController.view.frame = CGRect(x: 0, y: 0, width: contentWidth, height: timelineHeight)
                trimmerContainer.addSubview(hostingController.view)
                context.coordinator.timelineHostingController = hostingController
                context.coordinator.timelineView = hostingController.view
            } else {
                // Timeline이 이미 존재하면 rootView 업데이트
                context.coordinator.timelineHostingController?.rootView = AnyView(
                    VideoTimelineTrimmer(
                        videoAsset: videoAsset,
                        duration: safeDuration,
                        trimStartTime: trimStartTime,
                        trimEndTime: trimEndTime,
                        onTrimStartChanged: onTrimStartChanged,
                        onTrimEndChanged: onTrimEndChanged,
                        onLoadingChanged: { isLoading in
                            context.coordinator.updateLoadingIndicator(isLoading: isLoading)
                        }
                    )
                    .frame(width: contentWidth, height: timelineHeight)
                )

                // Frame 업데이트
                context.coordinator.timelineView?.frame = CGRect(x: 0, y: 0, width: contentWidth, height: timelineHeight)
            }
        }
        
        // 자막 영역 컨테이너
        if context.coordinator.subtitleContainer == nil {
            let subtitleContainer = UIView()
            subtitleContainer.backgroundColor = UIColor.systemGray6
            subtitleContainer.layer.cornerRadius = 4
            containerView.addSubview(subtitleContainer)
            context.coordinator.subtitleContainer = subtitleContainer
        }
        
        if let subtitleContainer = context.coordinator.subtitleContainer {
            subtitleContainer.frame = CGRect(x: timelinePadding, y: subtitleOriginY, width: timelineWidth - timelinePadding * 2, height: subtitleHeight)

            // 자막 블록들 업데이트
            // 현재 자막 ID 목록
            let currentSubtitleIds = Set(subtitles.map { $0.id })
            let cachedSubtitleIds = Set(context.coordinator.subtitleBlocks.keys)

            // 제거된 자막 블록 삭제
            for id in cachedSubtitleIds where !currentSubtitleIds.contains(id) {
                if let blockView = context.coordinator.subtitleBlocks[id] {
                    blockView.removeFromSuperview()
                    context.coordinator.subtitleBlocks.removeValue(forKey: id)
                }
            }

            // 자막 블록 업데이트 또는 생성
            let contentWidth = timelineWidth - timelinePadding * 2
            for subtitle in subtitles {
                let startPosition = safeDuration > 0 ? (subtitle.startTime / safeDuration) * contentWidth : 0
                let endPosition = safeDuration > 0 ? (subtitle.endTime / safeDuration) * contentWidth : 0
                let blockWidth = max(endPosition - startPosition, 20) // 최소 너비 20
                
                if let existingBlock = context.coordinator.subtitleBlocks[subtitle.id] {
                    // 기존 블록 업데이트
                    existingBlock.subtitle = subtitle
                    existingBlock.duration = safeDuration
                    existingBlock.timelineWidth = contentWidth
                    existingBlock.frame = CGRect(x: startPosition, y: 0, width: blockWidth, height: subtitleHeight)
                    existingBlock.updateTextLabel()
                } else {
                    // 새 블록 생성
                    let blockView = SubtitleBlockUIView(
                        subtitle: subtitle,
                        duration: safeDuration,
                        timelineWidth: contentWidth,
                        pixelsPerSecond: pixelsPerSecond,
                        onStartTimeChanged: onUpdateSubtitleStartTime,
                        onEndTimeChanged: onUpdateSubtitleEndTime,
                        onRemove: onRemoveSubtitle,
                        onEdit: onEditSubtitle
                    )
                    blockView.frame = CGRect(x: startPosition, y: 0, width: blockWidth, height: subtitleHeight)
                    subtitleContainer.addSubview(blockView)
                    context.coordinator.subtitleBlocks[subtitle.id] = blockView
                }
            }
        }

        // 배경음악 영역 컨테이너
        if context.coordinator.backgroundMusicContainer == nil {
            let musicContainer = UIView()
            musicContainer.backgroundColor = UIColor.systemGray6
            musicContainer.layer.cornerRadius = 4
            containerView.addSubview(musicContainer)
            context.coordinator.backgroundMusicContainer = musicContainer
        }

        if let musicContainer = context.coordinator.backgroundMusicContainer {
            musicContainer.frame = CGRect(x: timelinePadding, y: backgroundMusicOriginY, width: timelineWidth - timelinePadding * 2, height: backgroundMusicHeight)

            let contentWidth = timelineWidth - timelinePadding * 2

            // 배경음악 블록들 업데이트
            // 1. 기존 블록 중 삭제된 것 제거
            let currentMusicIDs = Set(backgroundMusics.map { $0.id })
            context.coordinator.backgroundMusicBlocks = context.coordinator.backgroundMusicBlocks.filter { blockView in
                if currentMusicIDs.contains(blockView.backgroundMusic.id) {
                    return true
                } else {
                    blockView.removeFromSuperview()
                    return false
                }
            }

            // 2. 각 배경음악에 대해 블록 생성 또는 업데이트
            for music in backgroundMusics {
                let startPosition = safeDuration > 0 ? (music.startTime / safeDuration) * contentWidth : 0
                let endPosition = safeDuration > 0 ? (music.endTime / safeDuration) * contentWidth : 0
                let blockWidth = max(endPosition - startPosition, 20) // 최소 너비 20

                if let existingBlock = context.coordinator.backgroundMusicBlocks.first(where: { $0.backgroundMusic.id == music.id }) {
                    // 기존 블록 업데이트
                    let previousURL = existingBlock.backgroundMusic.musicURL
                    existingBlock.backgroundMusic = music
                    existingBlock.duration = safeDuration
                    existingBlock.timelineWidth = contentWidth
                    existingBlock.frame = CGRect(x: startPosition, y: 0, width: blockWidth, height: backgroundMusicHeight)
                    existingBlock.updateLabel()

                    // 음악이 변경되었으면 waveform 다시 그리기
                    if previousURL != music.musicURL {
                        existingBlock.updateWaveform()
                    }
                } else {
                    // 새 블록 생성
                    let blockView = BackgroundMusicBlockUIView(
                        backgroundMusic: music,
                        duration: safeDuration,
                        timelineWidth: contentWidth,
                        pixelsPerSecond: pixelsPerSecond,
                        onStartTimeChanged: { time in
                            onUpdateBackgroundMusicStartTime(music.id, time)
                        },
                        onEndTimeChanged: { time in
                            onUpdateBackgroundMusicEndTime(music.id, time)
                        },
                        onRemove: {
                            onRemoveBackgroundMusic(music.id)
                        }
                    )
                    blockView.frame = CGRect(x: startPosition, y: 0, width: blockWidth, height: backgroundMusicHeight)
                    musicContainer.addSubview(blockView)
                    context.coordinator.backgroundMusicBlocks.append(blockView)
                }
            }
        }

        // Playhead view 업데이트 (배경음악 영역까지 확장)
        if context.coordinator.playheadView == nil {
            let playheadView = PlayheadUIView(frame: CGRect(x: 0, y: 0, width: 12, height: totalHeight))
            playheadView.layer.zPosition = 1000
            playheadView.rulerHeight = rulerHeight
            playheadView.gapHeight = gapBetweenRulerAndTimeline
            playheadView.duration = safeDuration
            playheadView.timelineWidth = timelineWidth
            playheadView.padding = timelinePadding
            playheadView.onSeek = onSeek
            containerView.addSubview(playheadView)
            context.coordinator.playheadView = playheadView
            playheadView.setNeedsDisplay()
        }

        if let playheadView = context.coordinator.playheadView {
            let oldHeight = playheadView.frame.size.height
            let newHeight = totalHeight

            // 높이가 변경되면 다시 그리기
            if oldHeight != newHeight {
                playheadView.frame.size.height = newHeight
                playheadView.setNeedsDisplay()
            }

            // 최신 ruler/gap 값 전달
            playheadView.rulerHeight = rulerHeight
            playheadView.gapHeight = gapBetweenRulerAndTimeline
            playheadView.duration = safeDuration
            playheadView.timelineWidth = timelineWidth
            playheadView.padding = timelinePadding
            playheadView.onSeek = onSeek
            
            // playhead를 항상 맨 앞으로
            containerView.bringSubviewToFront(playheadView)
            playheadView.layer.zPosition = 1000
            
            // seek 중이면 애니메이션 없이 바로 이동
            if context.coordinator.isSeeking {
                playheadView.frame.origin.x = playheadPosition - 6
            } else {
                UIView.animate(withDuration: 0.1, delay: 0, options: [.curveLinear], animations: {
                    playheadView.frame.origin.x = playheadPosition - 6
                })
            }
        }
        
        // 현재 시간 텍스트 라벨 업데이트 (시간 표시 컨테이너에 추가)
        if let timeContainer = context.coordinator.timeDisplayContainer {
            if context.coordinator.timeLabel == nil {
                let timeLabel = UILabel()
                timeLabel.font = timeFont
                timeLabel.textColor = .white
                timeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                timeLabel.textAlignment = .center
                timeLabel.layer.cornerRadius = 4
                timeLabel.layer.masksToBounds = true
                timeLabel.layer.zPosition = 1001
                timeContainer.addSubview(timeLabel)
                context.coordinator.timeLabel = timeLabel
            }
            
            if let timeLabel = context.coordinator.timeLabel {
                timeLabel.font = timeFont
                
                let timeText = formatTimeInSeconds(currentTime)
                timeLabel.text = timeText
                timeLabel.sizeToFit()
                timeLabel.frame.size.width += 12  // 좌우 패딩
                timeLabel.frame.size.height = 20
                
                timeContainer.bringSubviewToFront(timeLabel)
                
                // seek 중이면 애니메이션 없이 바로 이동
                if context.coordinator.isSeeking {
                    timeLabel.center = CGPoint(x: playheadPosition, y: 10)
                } else {
                    UIView.animate(withDuration: 0.1, delay: 0, options: [.curveLinear], animations: {
                        timeLabel.center = CGPoint(x: playheadPosition, y: 10)
                    })
                }
            }
        }
        
        // 스크롤 자동 조정 (재생 중일 때만 playhead가 화면 중앙에 오도록)
        if isPlaying {
            let targetOffsetX = playheadPosition - screenWidth / 2
            let maxOffsetX = max(0, timelineWidth - screenWidth)
            let clampedOffsetX = max(0, min(targetOffsetX, maxOffsetX))

            // seek 중이면 애니메이션 없이 바로 이동
            if context.coordinator.isSeeking {
                scrollView.contentOffset.x = clampedOffsetX
            } else {
                UIView.animate(withDuration: 0.1, delay: 0, options: [.curveLinear], animations: {
                    scrollView.contentOffset.x = clampedOffsetX
                })
            }
        }
        
        // seekTarget 플래그 설정/해제
        if seekTarget != nil && !context.coordinator.isSeeking {
            context.coordinator.isSeeking = true
        } else if seekTarget == nil && context.coordinator.isSeeking {
            // 약간의 딜레이 후 플래그 해제 (UI 업데이트가 완료될 때까지)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                context.coordinator.isSeeking = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func formatTimeInSeconds(_ time: Double) -> String {
        let seconds = Int(time)
        return "\(seconds)s"
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var containerView: UIView?
        var timeDisplayContainer: UIView?  // 시간 표시 컨테이너 (눈금자 + 현재 시간)
        var trimmerContainer: UIView?      // VideoTimelineTrimmer 컨테이너
        var subtitleContainer: UIView?     // 자막 컨테이너
        var backgroundMusicContainer: UIView?  // 배경음악 컨테이너
        var playheadView: PlayheadUIView?
        var timelineView: UIView?
        var timelineHostingController: UIHostingController<AnyView>?
        var rulerView: TimeRulerView?
        var timeLabel: UILabel?
        var isSeeking = false  // seek 중인지 추적
        var subtitleBlocks: [UUID: SubtitleBlockUIView] = [:]  // 자막 블록 캐시
        var backgroundMusicBlocks: [BackgroundMusicBlockUIView] = []  // 배경음악 블록들
        var loadingIndicatorView: UIView?  // 로딩 indicator (화면 중앙에 배치)
        weak var scrollView: UIScrollView?  // ScrollView 참조
        var timelineOriginY: CGFloat = 0  // 타임라인 Y 위치
        var timelineHeight: CGFloat = 0  // 타임라인 높이

        func updateLoadingIndicator(isLoading: Bool) {
            guard let scrollView = scrollView else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                if isLoading {
                    // indicator 생성
                    if self.loadingIndicatorView == nil {
                        let activityIndicator = UIActivityIndicatorView(style: .medium)
                        activityIndicator.color = .gray
                        activityIndicator.startAnimating()

                        scrollView.addSubview(activityIndicator)
                        self.loadingIndicatorView = activityIndicator

                        // 위치 설정
                        let centerX = scrollView.bounds.width / 2
                        let centerY = self.timelineOriginY + self.timelineHeight / 2
                        activityIndicator.center = CGPoint(x: centerX, y: centerY)
                    }
                } else {
                    // indicator 제거
                    if let indicatorView = self.loadingIndicatorView {
                        indicatorView.removeFromSuperview()
                        self.loadingIndicatorView = nil
                    }
                }
            }
        }
    }
}

// MARK: - Time Ruler View
private class TimeRulerView: UIView {
    var duration: Double = 0
    var pixelsPerSecond: CGFloat = 50
    var padding: CGFloat = 20
    var onSeek: ((Double) -> Void)?
    private let timeFont = UIFont.systemFont(ofSize: 14, weight: .regular)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGesture()
    }

    private func setupGesture() {
        // Pan gesture로 변경하여 드래그 중에도 seek 가능
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)

        // Tap gesture도 유지 (빠른 터치용)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)

        isUserInteractionEnabled = true
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        // 패딩을 고려한 시간 계산
        let adjustedX = location.x - padding
        let tappedTime = Double(adjustedX) / Double(pixelsPerSecond)
        let clampedTime = min(max(tappedTime, 0), duration)
        onSeek?(clampedTime)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        // 패딩을 고려한 시간 계산
        let adjustedX = location.x - padding
        let tappedTime = Double(adjustedX) / Double(pixelsPerSecond)
        let clampedTime = min(max(tappedTime, 0), duration)
        onSeek?(clampedTime)
    }
    
    override func draw(_ rect: CGRect) {
        guard UIGraphicsGetCurrentContext() != nil else { return }

        // 배경
        UIColor.systemGray6.setFill()
        UIRectFill(rect)

        // 텍스트 속성
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: timeFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]

        // 1초 간격으로 눈금 그리기 (실제 duration 이하의 시간만 표기)
        let totalSeconds = Int(duration)
        for second in 0...totalSeconds {
            // 패딩을 고려한 x 위치
            let xPosition = padding + CGFloat(second) * pixelsPerSecond

            // 세로선 그리기
            UIColor.separator.setStroke()
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: xPosition, y: rect.height - 5))
            linePath.addLine(to: CGPoint(x: xPosition, y: rect.height))
            linePath.lineWidth = 1
            linePath.stroke()

            // 시간 텍스트 그리기
            let timeText = "\(second)s"
            let textSize = (timeText as NSString).size(withAttributes: attributes)
            // 중앙 정렬
            let textX = xPosition - textSize.width / 2
            let textRect = CGRect(
                x: textX,
                y: 2,
                width: textSize.width,
                height: textSize.height
            )
            (timeText as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - Playhead UIView
private class PlayheadUIView: UIView {
    // 눈금자 높이와 그 아래 gap 높이 (삼각형은 gap에, 선은 그 아래에서 시작)
    var rulerHeight: CGFloat = 20
    var gapHeight: CGFloat = 16
    var duration: Double = 0
    var timelineWidth: CGFloat = 0
    var padding: CGFloat = 0
    var onSeek: ((Double) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.contentMode = .redraw
        setupGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview, duration > 0, timelineWidth > 0 else { return }

        let location = gesture.location(in: superview)

        // padding을 고려한 시간 계산
        let adjustedX = location.x - padding
        let tappedTime = Double(adjustedX) / Double((timelineWidth - padding * 2) / CGFloat(duration))
        let clampedTime = min(max(tappedTime, 0), duration)

        onSeek?(clampedTime)
    }
    
    override func draw(_ rect: CGRect) {
        guard UIGraphicsGetCurrentContext() != nil else { return }
        
        UIColor.black.setFill()
        
        // 삼각형 영역: 눈금자 아래 gap 공간 중앙에 배치
        let triangleHeight = min(12, max(6, gapHeight * 0.8)) // gap에 맞춘 적당한 높이
        let triangleTopY = rulerHeight + (gapHeight - triangleHeight) / 2
        let triangleBottomY = triangleTopY + triangleHeight
        
        // 상단 삼각형 (▼)
        let trianglePath = UIBezierPath()
        trianglePath.move(to: CGPoint(x: rect.midX, y: triangleBottomY))      // 아래 꼭지점
        trianglePath.addLine(to: CGPoint(x: rect.midX - 6, y: triangleTopY))  // 왼쪽 위
        trianglePath.addLine(to: CGPoint(x: rect.midX + 6, y: triangleTopY))  // 오른쪽 위
        trianglePath.close()
        trianglePath.fill()
        
        // 세로선: gap 아래부터 아래로 그리기
        let lineRect = CGRect(x: rect.midX - 1, y: rulerHeight + gapHeight, width: 2, height: rect.height - (rulerHeight + gapHeight))
        if lineRect.height > 0 {
            UIBezierPath(rect: lineRect).fill()
        }
    }
}

private struct VideoTimelineTrimmer: View {
    let videoAsset: PHAsset
    let duration: Double
    let trimStartTime: Double
    let trimEndTime: Double
    let onTrimStartChanged: (Double) -> Void
    let onTrimEndChanged: (Double) -> Void
    let onLoadingChanged: (Bool) -> Void

    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    
    private let handleWidth: CGFloat = 12
    private let minTrimDuration: Double = 0.1

    // 썸네일 개수: 3초마다 1개
    private var thumbnailCount: Int {
        guard duration > 0 else { return 1 }
        return max(1, Int(ceil(duration / 3.0)))
    }
    
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
                    size: geometry.size,
                    onLoadingChanged: onLoadingChanged
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
                
                // 왼쪽 핸들 (시작 시간) - 썸네일 안쪽 왼쪽에 위치
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
                
                // 오른쪽 핸들 (종료 시간) - 썸네일 안쪽 오른쪽에 위치
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
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.blue)
            .frame(width: handleWidth, height: height)
            .overlay(
                // 핸들 그립 라인
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 12)
            )
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
    let onLoadingChanged: (Bool) -> Void

    @State private var thumbnails: [UIImage] = []
    @State private var isLoadingThumbnails = false {
        didSet {
            onLoadingChanged(isLoadingThumbnails)
        }
    }

    var body: some View {
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
                        .fill(Color(uiColor: UIColor.systemGray6))
                        .frame(width: thumbnailWidth, height: height)
                }
            }
        }
        .cornerRadius(4)
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

// MARK: - Subtitle Block UIView
private class SubtitleBlockUIView: UIView {
    private let handleWidth: CGFloat = 12
    var subtitle: EditVideoFeature.Subtitle
    var duration: Double
    var timelineWidth: CGFloat
    var pixelsPerSecond: CGFloat
    var onStartTimeChanged: ((UUID, Double) -> Void)?
    var onEndTimeChanged: ((UUID, Double) -> Void)?
    var onRemove: ((UUID) -> Void)?
    var onEdit: ((UUID) -> Void)?

    private var leftHandle: UIView!
    private var rightHandle: UIView!
    private var removeButton: UIButton!
    private var textLabel: UILabel!

    init(
        subtitle: EditVideoFeature.Subtitle,
        duration: Double,
        timelineWidth: CGFloat,
        pixelsPerSecond: CGFloat,
        onStartTimeChanged: @escaping (UUID, Double) -> Void,
        onEndTimeChanged: @escaping (UUID, Double) -> Void,
        onRemove: @escaping (UUID) -> Void,
        onEdit: @escaping (UUID) -> Void
    ) {
        self.subtitle = subtitle
        self.duration = duration
        self.timelineWidth = timelineWidth
        self.pixelsPerSecond = pixelsPerSecond
        self.onStartTimeChanged = onStartTimeChanged
        self.onEndTimeChanged = onEndTimeChanged
        self.onRemove = onRemove
        self.onEdit = onEdit

        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6)
        layer.cornerRadius = 4
        clipsToBounds = true

        // 왼쪽 핸들
        leftHandle = UIView()
        leftHandle.backgroundColor = UIColor.systemBlue
        leftHandle.layer.cornerRadius = 4
        addSubview(leftHandle)

        // 왼쪽 핸들 그립 라인
        let leftGrip = UIView()
        leftGrip.backgroundColor = .white
        leftGrip.layer.cornerRadius = 1
        leftHandle.addSubview(leftGrip)
        leftGrip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leftGrip.centerXAnchor.constraint(equalTo: leftHandle.centerXAnchor),
            leftGrip.centerYAnchor.constraint(equalTo: leftHandle.centerYAnchor),
            leftGrip.widthAnchor.constraint(equalToConstant: 2),
            leftGrip.heightAnchor.constraint(equalToConstant: 12)
        ])

        let leftPan = UIPanGestureRecognizer(target: self, action: #selector(handleLeftPan(_:)))
        leftHandle.addGestureRecognizer(leftPan)
        leftHandle.isUserInteractionEnabled = true

        // 오른쪽 핸들
        rightHandle = UIView()
        rightHandle.backgroundColor = UIColor.systemBlue
        rightHandle.layer.cornerRadius = 4
        addSubview(rightHandle)

        // 오른쪽 핸들 그립 라인
        let rightGrip = UIView()
        rightGrip.backgroundColor = .white
        rightGrip.layer.cornerRadius = 1
        rightHandle.addSubview(rightGrip)
        rightGrip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rightGrip.centerXAnchor.constraint(equalTo: rightHandle.centerXAnchor),
            rightGrip.centerYAnchor.constraint(equalTo: rightHandle.centerYAnchor),
            rightGrip.widthAnchor.constraint(equalToConstant: 2),
            rightGrip.heightAnchor.constraint(equalToConstant: 12)
        ])

        let rightPan = UIPanGestureRecognizer(target: self, action: #selector(handleRightPan(_:)))
        rightHandle.addGestureRecognizer(rightPan)
        rightHandle.isUserInteractionEnabled = true

        // 텍스트 라벨
        textLabel = UILabel()
        textLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        textLabel.textColor = .white
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 2
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.isUserInteractionEnabled = true
        addSubview(textLabel)
        updateTextLabel()

        // 텍스트 라벨 탭 제스처 (자막 수정)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        textLabel.addGestureRecognizer(tapGesture)

        // 제거 버튼
        removeButton = UIButton(type: .custom)
        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .white
        removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        removeButton.layer.cornerRadius = 8
        removeButton.addTarget(self, action: #selector(handleRemove), for: .touchUpInside)
        addSubview(removeButton)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        // 왼쪽 핸들
        leftHandle.frame = CGRect(x: 0, y: 0, width: handleWidth, height: bounds.height)

        // 오른쪽 핸들
        rightHandle.frame = CGRect(x: bounds.width - handleWidth, y: 0, width: handleWidth, height: bounds.height)

        // 제거 버튼
        removeButton.frame = CGRect(x: bounds.width - handleWidth - 4 - 16, y: 4, width: 16, height: 16)

        // 텍스트 라벨 (핸들과 제거 버튼 사이 영역, 제거 버튼 공간 제외)
        let textX = handleWidth + 4
        let textWidth = bounds.width - handleWidth * 2 - 8 - 16 - 4 // 제거 버튼(16) + 간격(4) 제외
        textLabel.frame = CGRect(x: textX, y: 0, width: textWidth, height: bounds.height)
    }
    
    func updateTextLabel() {
        textLabel.text = subtitle.text.isEmpty ? "" : subtitle.text
    }
    
    func updatePosition() {
        // 프레임 업데이트 (외부에서 호출)
        let startPosition = duration > 0 ? (subtitle.startTime / duration) * timelineWidth : 0
        let endPosition = duration > 0 ? (subtitle.endTime / duration) * timelineWidth : 0
        let blockWidth = max(endPosition - startPosition, 20)
        
        self.frame = CGRect(x: startPosition, y: self.frame.origin.y, width: blockWidth, height: self.frame.height)
    }
    
    @objc private func handleLeftPan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        
        if gesture.state == .changed {
            // superview 내에서의 터치 위치
            let location = gesture.location(in: superview)
            
            // 새로운 시작 위치
            let newStartPosition = max(0, location.x)
            
            // 끝 위치 계산
            let endPosition = (subtitle.endTime / duration) * timelineWidth
            
            // 최소 너비 유지 (0.5초에 해당하는 픽셀)
            let minWidth = (0.5 / duration) * timelineWidth
            let clampedPosition = min(newStartPosition, endPosition - minWidth)
            
            // 시간으로 변환
            let newStartTime = (clampedPosition / timelineWidth) * duration
            let clampedTime = max(0, min(newStartTime, subtitle.endTime - 0.5))
            
            // 즉시 프레임 업데이트 (드래그 중에는 애니메이션 없음)
            let blockWidth = endPosition - clampedPosition
            self.frame = CGRect(x: clampedPosition, y: self.frame.origin.y, width: blockWidth, height: self.frame.height)
            
            // 상태 업데이트 콜백
            onStartTimeChanged?(subtitle.id, clampedTime)
        }
    }
    
    @objc private func handleRightPan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        
        if gesture.state == .changed {
            // superview 내에서의 터치 위치
            let location = gesture.location(in: superview)
            
            // 새로운 끝 위치
            let newEndPosition = min(timelineWidth, location.x)
            
            // 시작 위치 계산
            let startPosition = (subtitle.startTime / duration) * timelineWidth
            
            // 최소 너비 유지 (0.5초에 해당하는 픽셀)
            let minWidth = (0.5 / duration) * timelineWidth
            let clampedPosition = max(newEndPosition, startPosition + minWidth)
            
            // 시간으로 변환
            let newEndTime = (clampedPosition / timelineWidth) * duration
            let clampedTime = min(duration, max(newEndTime, subtitle.startTime + 0.5))
            
            // 즉시 프레임 업데이트 (드래그 중에는 애니메이션 없음)
            let blockWidth = clampedPosition - startPosition
            self.frame = CGRect(x: startPosition, y: self.frame.origin.y, width: blockWidth, height: self.frame.height)
            
            // 상태 업데이트 콜백
            onEndTimeChanged?(subtitle.id, clampedTime)
        }
    }
    
    @objc private func handleRemove() {
        onRemove?(subtitle.id)
    }

    @objc private func handleTap() {
        onEdit?(subtitle.id)
    }
}

// MARK: - Background Music Block UIView
private class BackgroundMusicBlockUIView: UIView {
    private let handleWidth: CGFloat = 12
    var backgroundMusic: EditVideoFeature.BackgroundMusic
    var duration: Double
    var timelineWidth: CGFloat
    var pixelsPerSecond: CGFloat
    var onStartTimeChanged: ((Double) -> Void)?
    var onEndTimeChanged: ((Double) -> Void)?
    var onRemove: (() -> Void)?

    private var leftHandle: UIView!
    private var rightHandle: UIView!
    private var removeButton: UIButton!
    private var textLabel: UILabel!
    private var waveformView: UIView!

    init(
        backgroundMusic: EditVideoFeature.BackgroundMusic,
        duration: Double,
        timelineWidth: CGFloat,
        pixelsPerSecond: CGFloat,
        onStartTimeChanged: @escaping (Double) -> Void,
        onEndTimeChanged: @escaping (Double) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.backgroundMusic = backgroundMusic
        self.duration = duration
        self.timelineWidth = timelineWidth
        self.pixelsPerSecond = pixelsPerSecond
        self.onStartTimeChanged = onStartTimeChanged
        self.onEndTimeChanged = onEndTimeChanged
        self.onRemove = onRemove

        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6)
        layer.cornerRadius = 4
        clipsToBounds = true

        // 왼쪽 핸들
        leftHandle = UIView()
        leftHandle.backgroundColor = UIColor.systemBlue
        leftHandle.layer.cornerRadius = 4
        addSubview(leftHandle)

        // 왼쪽 핸들 그립 라인
        let leftGrip = UIView()
        leftGrip.backgroundColor = .white
        leftGrip.layer.cornerRadius = 1
        leftHandle.addSubview(leftGrip)
        leftGrip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leftGrip.centerXAnchor.constraint(equalTo: leftHandle.centerXAnchor),
            leftGrip.centerYAnchor.constraint(equalTo: leftHandle.centerYAnchor),
            leftGrip.widthAnchor.constraint(equalToConstant: 2),
            leftGrip.heightAnchor.constraint(equalToConstant: 12)
        ])

        let leftPan = UIPanGestureRecognizer(target: self, action: #selector(handleLeftPan(_:)))
        leftHandle.addGestureRecognizer(leftPan)
        leftHandle.isUserInteractionEnabled = true

        // 오른쪽 핸들
        rightHandle = UIView()
        rightHandle.backgroundColor = UIColor.systemBlue
        rightHandle.layer.cornerRadius = 4
        addSubview(rightHandle)

        // 오른쪽 핸들 그립 라인
        let rightGrip = UIView()
        rightGrip.backgroundColor = .white
        rightGrip.layer.cornerRadius = 1
        rightHandle.addSubview(rightGrip)
        rightGrip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rightGrip.centerXAnchor.constraint(equalTo: rightHandle.centerXAnchor),
            rightGrip.centerYAnchor.constraint(equalTo: rightHandle.centerYAnchor),
            rightGrip.widthAnchor.constraint(equalToConstant: 2),
            rightGrip.heightAnchor.constraint(equalToConstant: 12)
        ])

        let rightPan = UIPanGestureRecognizer(target: self, action: #selector(handleRightPan(_:)))
        rightHandle.addGestureRecognizer(rightPan)
        rightHandle.isUserInteractionEnabled = true

        // Waveform 배경 뷰
        waveformView = UIView()
        waveformView.backgroundColor = .clear
        addSubview(waveformView)
        sendSubviewToBack(waveformView)

        // 텍스트 라벨
        textLabel = UILabel()
        textLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        textLabel.textColor = .white
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 1
        addSubview(textLabel)
        updateLabel()
        updateWaveform()

        // 제거 버튼
        removeButton = UIButton(type: .custom)
        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .white
        removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        removeButton.layer.cornerRadius = 8
        removeButton.addTarget(self, action: #selector(handleRemove), for: .touchUpInside)
        addSubview(removeButton)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Waveform 뷰 (전체 영역)
        waveformView.frame = bounds

        // 왼쪽 핸들
        leftHandle.frame = CGRect(x: 0, y: 0, width: handleWidth, height: bounds.height)

        // 오른쪽 핸들
        rightHandle.frame = CGRect(x: bounds.width - handleWidth, y: 0, width: handleWidth, height: bounds.height)

        // 제거 버튼
        removeButton.frame = CGRect(x: bounds.width - handleWidth - 4 - 16, y: 4, width: 16, height: 16)

        // 텍스트 라벨 (핸들과 제거 버튼 사이 영역, 제거 버튼 공간 제외)
        let textX = handleWidth + 4
        let textWidth = bounds.width - handleWidth * 2 - 8 - 16 - 4 // 제거 버튼(16) + 간격(4) 제외
        textLabel.frame = CGRect(x: textX, y: 0, width: textWidth, height: bounds.height)
    }

    func updateLabel() {
        textLabel.text = ""
    }

    func updatePosition() {
        // 프레임 업데이트 (외부에서 호출)
        let startPosition = duration > 0 ? (backgroundMusic.startTime / duration) * timelineWidth : 0
        let endPosition = duration > 0 ? (backgroundMusic.endTime / duration) * timelineWidth : 0
        let blockWidth = max(endPosition - startPosition, 20)

        self.frame = CGRect(x: startPosition, y: self.frame.origin.y, width: blockWidth, height: self.frame.height)
    }

    func updateWaveform() {
        // 기존 레이어 제거
        waveformView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // 비동기로 waveform 생성
        Task {
            let samples = await extractAudioSamples(from: backgroundMusic.musicURL, targetSampleCount: 300)
            await MainActor.run {
                drawWaveform(samples: samples)
            }
        }
    }

    private func extractAudioSamples(from url: URL, targetSampleCount: Int) async -> [Float] {
        let asset = AVAsset(url: url)

        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return []
        }

        let reader: AVAssetReader
        let readerOutput: AVAssetReaderTrackOutput

        do {
            reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            reader.add(readerOutput)
        } catch {
            return []
        }

        reader.startReading()

        var samples: [Float] = []
        var sampleCount = 0
        let maxSamples = 100000 // 샘플링할 최대 샘플 수

        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)

            _ = data.withUnsafeMutableBytes { ptr in
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
            }

            let int16Array = data.withUnsafeBytes { $0.bindMemory(to: Int16.self) }
            for sample in int16Array {
                if sampleCount >= maxSamples { break }
                samples.append(Float(sample) / Float(Int16.max))
                sampleCount += 1
            }

            if sampleCount >= maxSamples { break }
        }

        // 다운샘플링하여 targetSampleCount 개로 줄이기
        if samples.count > targetSampleCount {
            let step = samples.count / targetSampleCount
            samples = Swift.stride(from: 0, to: samples.count, by: step).map { samples[$0] }
        }

        return samples
    }

    private func drawWaveform(samples: [Float]) {
        guard !samples.isEmpty, waveformView.bounds.width > 0 else { return }

        let path = UIBezierPath()
        let width = waveformView.bounds.width
        let height = waveformView.bounds.height
        let midY = height / 2
        let barWidth: CGFloat = max(0.5, width / CGFloat(samples.count))
        let heightScale = height * 0.9 // 파형 높이 스케일

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(abs(sample)) * heightScale

            path.move(to: CGPoint(x: x, y: midY - barHeight / 2))
            path.addLine(to: CGPoint(x: x, y: midY + barHeight / 2))
        }

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        shapeLayer.lineWidth = max(0.5, barWidth * 0.8)
        shapeLayer.lineCap = .round

        waveformView.layer.addSublayer(shapeLayer)
    }

    @objc private func handleLeftPan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }

        if gesture.state == .changed {
            // superview 내에서의 터치 위치
            let location = gesture.location(in: superview)

            // 새로운 시작 위치
            let newStartPosition = max(0, location.x)

            // 끝 위치 계산
            let endPosition = (backgroundMusic.endTime / duration) * timelineWidth

            // 최소 너비 유지 (0.5초에 해당하는 픽셀)
            let minWidth = (0.5 / duration) * timelineWidth
            let clampedPosition = min(newStartPosition, endPosition - minWidth)

            // 시간으로 변환
            let newStartTime = (clampedPosition / timelineWidth) * duration
            let clampedTime = max(0, min(newStartTime, backgroundMusic.endTime - 0.5))

            // 즉시 프레임 업데이트 (드래그 중에는 애니메이션 없음)
            let blockWidth = endPosition - clampedPosition
            self.frame = CGRect(x: clampedPosition, y: self.frame.origin.y, width: blockWidth, height: self.frame.height)

            // 상태 업데이트 콜백
            onStartTimeChanged?(clampedTime)
        }
    }

    @objc private func handleRightPan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }

        if gesture.state == .changed {
            // superview 내에서의 터치 위치
            let location = gesture.location(in: superview)

            // 새로운 끝 위치
            let newEndPosition = min(timelineWidth, location.x)

            // 시작 위치 계산
            let startPosition = (backgroundMusic.startTime / duration) * timelineWidth

            // 최소 너비 유지 (0.5초에 해당하는 픽셀)
            let minWidth = (0.5 / duration) * timelineWidth
            let clampedPosition = max(newEndPosition, startPosition + minWidth)

            // 시간으로 변환
            let newEndTime = (clampedPosition / timelineWidth) * duration
            let clampedTime = min(duration, max(newEndTime, backgroundMusic.startTime + 0.5))

            // 즉시 프레임 업데이트 (드래그 중에는 애니메이션 없음)
            let blockWidth = clampedPosition - startPosition
            self.frame = CGRect(x: startPosition, y: self.frame.origin.y, width: blockWidth, height: self.frame.height)

            // 상태 업데이트 콜백
            onEndTimeChanged?(clampedTime)
        }
    }

    @objc private func handleRemove() {
        onRemove?()
    }
}

// MARK: - Filter Selection View
private struct FilterSelectionView: View {
    let selectedFilter: VideoFilter?
    let purchasedFilterTypes: Set<VideoFilter>  // 구매한 필터 타입
    let onFilterSelected: (VideoFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppPadding.medium) {
                ForEach(VideoFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        isPurchased: isPurchased(filter),
                        action: {
                            onFilterSelected(filter)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // 필터 구매 여부 확인
    private func isPurchased(_ filter: VideoFilter) -> Bool {
        // 유료 필터가 아니면 항상 true
        guard filter.isPaid else { return true }

        // 캐시된 purchasedFilterTypes에서 확인 (동기적으로)
        return purchasedFilterTypes.contains(filter)
    }
}

// MARK: - Filter Button
private struct FilterButton: View {
    let filter: VideoFilter
    let isSelected: Bool
    let isPurchased: Bool  // 구매 여부
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // 필터 미리보기
                ZStack {
                    Image(image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .customRadius()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? Color(uiColor: UIColor.systemBlue) : Color.clear, lineWidth: 4)
                        )

                    // Lock/Unlock 아이콘 (유료 필터인 경우)
                    if filter.isPaid {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: isPurchased ? "lock.open.fill" : "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(isPurchased ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                                    .clipShape(Circle())
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }

                // 필터 이름
                Text(filter.displayName)
                    .font(.appCaption)
                    .foregroundStyle(isSelected ? Color(uiColor: UIColor.systemBlue) : .black)
            }
        }
    }
    
    var image: String {
        switch filter {
        case .blackAndWhite:
            return "video_mono"
        case .warm:
            return "video_warm"
        case .cool:
            return "video_cool"
        case .animeGANHayao:
            return "video_anime"
        }
    }
}

// MARK: - Exporting Overlay View
private struct ExportingOverlayView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
            
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

// MARK: - Music Selection Overlay View
private struct MusicSelectionOverlayView: View {
    let onSelectMusic: (URL) -> Void
    let onCancel: () -> Void

    @State private var playingMusicURL: URL? = nil
    @State private var audioPlayer: AVPlayer? = nil

    private let availableMusic: [(name: String, url: URL, duration: String)] = [
        (
            name: "ailawyer 15/12",
            url: Bundle.main.url(forResource: "ailawyer-1512", withExtension: "mp3")!,
            duration: "02:40"
        ),
        (
            name: "Lament of Eleusis",
            url: Bundle.main.url(forResource: "lament-of-eleusis", withExtension: "mp3")!,
            duration: "01:41"
        )
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)

            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Text("배경음악 선택")
                        .font(.headline)
                        .foregroundStyle(.black)

                    Spacer()

                    Button {
                        onCancel()
                    } label: {
                        AppIcon.xmark
                            .foregroundStyle(.gray)
                    }
                }
                .padding()
                .background(Color.white)

                Divider()

                // 음악 목록
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(availableMusic, id: \.url) { music in
                            Button {
                                onSelectMusic(music.url)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(music.name)
                                            .font(.body)
                                            .foregroundStyle(.black)

                                        Text(music.duration)
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }

                                    Spacer()

                                    Button {
                                        togglePlayMusic(url: music.url)
                                    } label: {
                                        AppIcon.speaker
                                            .foregroundStyle(playingMusicURL == music.url ? .blue : .gray)
                                    }
                                }
                                .padding()
                            }

                            if music.url != availableMusic.last?.url {
                                Divider()
                            }
                        }
                    }
                }
                .background(Color.white)
            }
            .frame(width: 320, height: 300)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 20)
        }
        .onDisappear {
            stopMusic()
        }
    }

    private func togglePlayMusic(url: URL) {
        if playingMusicURL == url {
            // 같은 음악을 다시 누르면 정지
            stopMusic()
        } else {
            // 다른 음악 재생
            playMusic(url: url)
        }
    }

    private func playMusic(url: URL) {
        // 기존 재생 중지
        audioPlayer?.pause()

        // 새 음악 재생
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        audioPlayer = player
        playingMusicURL = url
        player.play()

        // 음악 종료 감지
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            playingMusicURL = nil
        }
    }

    private func stopMusic() {
        audioPlayer?.pause()
        audioPlayer = nil
        playingMusicURL = nil
    }
}

// MARK: - Subtitle Input Overlay View
private struct SubtitleInputOverlayView: View {
    @Binding var text: String
    let errorMessage: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    private var isConfirmDisabled: Bool {
        text.isEmpty || errorMessage != nil
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            
            VStack(spacing: 0) {
                Spacer()
                
                TextField("", text: $text)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .background(.clear)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if !isConfirmDisabled {
                            onConfirm()
                        }
                    }
                    .multilineTextAlignment(.center)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button("취소") {
                                onCancel()
                            }
                            .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Button("완료") {
                                onConfirm()
                            }
                            .foregroundStyle(isConfirmDisabled ? .gray : .white)
                            .disabled(isConfirmDisabled)
                        }
                    }
                
                Text(errorMessage ?? " ")
                    .font(.appCaption)
                    .foregroundStyle(.red)
                    .frame(height: 16)
                    .opacity(errorMessage == nil ? 0 : 1)
                
                Spacer()
            }
            .padding(.horizontal, AppPadding.large)
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Purchase Modal View
private struct PurchaseModalView: View {
    let viewStore: ViewStoreOf<EditVideoFeature>

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    viewStore.send(.dismissPurchaseModal)
                }

            VStack(spacing: 20) {
                // 헤더
                HStack {
                    Text("유료 필터 구매")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        viewStore.send(.dismissPurchaseModal)
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }

                Divider()

                if let paidFilter = viewStore.pendingPurchaseFilter {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(paidFilter.title)
                            .font(.headline)

                        Text(paidFilter.content)
                            .font(.body)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("가격:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(paidFilter.price)원")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }

                // 에러 메시지
                if let errorMessage = viewStore.paymentError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }

                // 구매 버튼
                Button {
                    viewStore.send(.purchaseButtonTapped)
                } label: {
                    if viewStore.isProcessingPayment {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("구매하기")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(viewStore.isProcessingPayment ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(viewStore.isProcessingPayment)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 20)
            .frame(maxWidth: 350)
        }
    }
}
