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
                            seekTarget: viewStore.seekTarget,
                            selectedFilter: viewStore.editState.selectedFilter,
                            onTimeUpdate: { time in viewStore.send(.updateCurrentTime(time)) },
                            onDurationUpdate: { duration in viewStore.send(.updateDuration(duration)) },
                            onSeekCompleted: { viewStore.send(.seekCompleted) },
                            onFilterApplied: { viewStore.send(.filterApplied) },
                            onPlaybackEnded: { viewStore.send(.playbackEnded) }
                        )
                    }
                    .overlay {
                        if viewStore.isApplyingFilter {
                            FilterApplyingOverlayView()
                        }
                    }

                // 재생 버튼과 타임라인 편집 영역
                HStack(alignment: .top, spacing: AppPadding.large) {
                    // 재생 버튼
                    VideoControlsView(
                        isPlaying: viewStore.isPlaying,
                        onPlayPause: { viewStore.send(.playPauseButtonTapped) }
                    )
                    .frame(width: 32, height: 32)
                    .padding(.leading, AppPadding.large)

                    VStack(spacing: AppPadding.large) {
                        // 시간 눈금자 + 가로 스크롤 가능한 타임라인 편집 영역
                        VideoTimelineEditor(
                            videoAsset: viewStore.videoAsset,
                            duration: viewStore.duration,
                            currentTime: viewStore.currentTime,
                            seekTarget: viewStore.seekTarget,
                            trimStartTime: viewStore.editState.trimStartTime,
                            trimEndTime: viewStore.editState.trimEndTime,
                            onTrimStartChanged: { time in
                                viewStore.send(.updateTrimStartTime(time))
                            },
                            onTrimEndChanged: { time in
                                viewStore.send(.updateTrimEndTime(time))
                            },
                            onSeek: { time in
                                viewStore.send(.seekToTime(time))
                            }
                        )
                        .frame(height: 120)
                        .offset(y: 6)
                        
                        // 필터 선택
                        FilterSelectionView(
                            selectedFilter: viewStore.editState.selectedFilter,
                            onFilterSelected: { filter in
                                viewStore.send(.filterSelected(filter))
                            }
                        )
                        .padding(.top, AppPadding.medium)
                    }
                }
                .padding(.top, AppPadding.large)

                Spacer()

            }
            .navigationTitle("영상 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewStore.send(.completeButtonTapped)
                    } label: {
                        Text("완료")
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

// MARK: - Video Timeline Editor (가로 스크롤 가능)
private struct VideoTimelineEditor: UIViewRepresentable {
    let videoAsset: PHAsset
    let duration: Double
    let currentTime: Double
    let seekTarget: Double?
    let trimStartTime: Double
    let trimEndTime: Double
    let onTrimStartChanged: (Double) -> Void
    let onTrimEndChanged: (Double) -> Void
    let onSeek: (Double) -> Void

    // 1초당 픽셀 수
    private let pixelsPerSecond: CGFloat = 50

    // 눈금자와 썸네일 타임라인 사이 간격 (삼각형이 들어갈 공간)
    private let gapBetweenRulerAndTimeline: CGFloat = 16

    // 핸들 너비 (VideoTimelineTrimmer와 동일)
    private let handleWidth: CGFloat = 12

    // 추가 왼쪽 여백 (레이블이 잘리지 않도록)
    private let extraLeftPadding: CGFloat = 4

    // 시간 Font
    private let timeFont = UIFont.systemFont(ofSize: 16, weight: .regular)

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator

        // 시작/끝 여백 추가 (왼쪽 여백 제거)
        let inset = AppPadding.large
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: inset)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: inset)
        
        let containerView = UIView()
        containerView.backgroundColor = .clear
        scrollView.addSubview(containerView)
        context.coordinator.containerView = containerView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let containerView = context.coordinator.containerView else { return }

        let screenWidth = scrollView.bounds.width
        
        // 안전한 width/height 계산 (음수/비유한 방지)
        let safeDuration = duration.isFinite && duration >= 0 ? duration : 0
        let timelineWidth = max(0, CGFloat(safeDuration) * pixelsPerSecond)

        let totalHeight = scrollView.bounds.height
        let rulerHeight: CGFloat = 20
        // 타임라인 시작 Y는 눈금자 아래 gap만큼 띄움
        let timelineOriginY = rulerHeight + gapBetweenRulerAndTimeline
        let timelineHeight = max(0, totalHeight - timelineOriginY)

        // 핸들이 좌우로 빠져있으므로 컨테이너 너비에 핸들 공간 + 추가 여백 추가
        let leftOffset = handleWidth + extraLeftPadding
        let containerWidth = timelineWidth + (handleWidth * 2) + extraLeftPadding

        // 현재 재생 헤드 위치 (leftOffset 고려)
        let playheadPosition = (safeDuration > 0 && timelineWidth > 0)
            ? (currentTime / safeDuration) * timelineWidth + leftOffset
            : leftOffset

        // Container 크기 설정 (핸들 영역 포함)
        containerView.frame = CGRect(x: 0, y: 0, width: containerWidth, height: totalHeight)
        scrollView.contentSize = CGSize(width: containerWidth, height: totalHeight)

        // 시간 표시 컨테이너 뷰 (눈금자 + 현재 시간 라벨)
        if context.coordinator.timeDisplayContainer == nil {
            let timeContainer = UIView()
            timeContainer.backgroundColor = .clear
            containerView.addSubview(timeContainer)
            context.coordinator.timeDisplayContainer = timeContainer
        }

        if let timeContainer = context.coordinator.timeDisplayContainer {
            // 눈금자 전체 너비 (좌우 핸들 공간 포함)
            let rulerTotalWidth = timelineWidth + (handleWidth * 2)

            // 컨테이너를 왼쪽 끝에서 시작
            timeContainer.frame = CGRect(x: extraLeftPadding, y: 0, width: rulerTotalWidth, height: rulerHeight)

            // 시간 눈금자 view 업데이트
            if context.coordinator.rulerView == nil {
                let rulerView = TimeRulerView(frame: CGRect(x: 0, y: 0, width: rulerTotalWidth, height: rulerHeight))
                rulerView.duration = safeDuration
                rulerView.pixelsPerSecond = pixelsPerSecond
                rulerView.backgroundColor = .clear
                rulerView.onSeek = onSeek
                rulerView.handleWidth = handleWidth
                timeContainer.addSubview(rulerView)
                context.coordinator.rulerView = rulerView
            } else {
                context.coordinator.rulerView?.frame = CGRect(x: 0, y: 0, width: rulerTotalWidth, height: rulerHeight)
                context.coordinator.rulerView?.duration = safeDuration
                context.coordinator.rulerView?.pixelsPerSecond = pixelsPerSecond
                context.coordinator.rulerView?.onSeek = onSeek
                context.coordinator.rulerView?.handleWidth = handleWidth
                context.coordinator.rulerView?.setNeedsDisplay()
            }
        }

        // VideoTimelineTrimmer 컨테이너 뷰 (썸네일 영역)
        if context.coordinator.trimmerContainer == nil {
            let trimmerContainer = UIView()
            trimmerContainer.backgroundColor = .clear
            containerView.addSubview(trimmerContainer)
            context.coordinator.trimmerContainer = trimmerContainer
        }

        if let trimmerContainer = context.coordinator.trimmerContainer {
            // leftOffset만큼 오른쪽으로 이동하여 핸들 공간 확보
            trimmerContainer.frame = CGRect(x: leftOffset, y: timelineOriginY, width: timelineWidth, height: timelineHeight)

            // Timeline trimmer view 업데이트
            if context.coordinator.timelineHostingController == nil {
                let hostingController = UIHostingController(rootView:
                    AnyView(
                        VideoTimelineTrimmer(
                            videoAsset: videoAsset,
                            duration: safeDuration,
                            trimStartTime: trimStartTime,
                            trimEndTime: trimEndTime,
                            onTrimStartChanged: onTrimStartChanged,
                            onTrimEndChanged: onTrimEndChanged
                        )
                        .frame(width: timelineWidth, height: timelineHeight)
                    )
                )
                hostingController.view.backgroundColor = .clear
                hostingController.view.frame = CGRect(x: 0, y: 0, width: timelineWidth, height: timelineHeight)
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
                        onTrimEndChanged: onTrimEndChanged
                    )
                    .frame(width: timelineWidth, height: timelineHeight)
                )

                // Frame 업데이트
                context.coordinator.timelineView?.frame = CGRect(x: 0, y: 0, width: timelineWidth, height: timelineHeight)
            }
        }

        // Playhead view 업데이트 (항상 최상위, 삼각형은 gap 공간에, 선은 그 아래)
        if context.coordinator.playheadView == nil {
            let playheadView = PlayheadUIView(frame: CGRect(x: 0, y: 0, width: 12, height: totalHeight))
            playheadView.layer.zPosition = 1000
            playheadView.rulerHeight = rulerHeight
            playheadView.gapHeight = gapBetweenRulerAndTimeline
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

                // timeContainer가 extraLeftPadding에서 시작하므로 상대 위치 조정
                let labelX = playheadPosition - extraLeftPadding

                // seek 중이면 애니메이션 없이 바로 이동
                if context.coordinator.isSeeking {
                    timeLabel.center = CGPoint(x: labelX, y: 10)
                } else {
                    UIView.animate(withDuration: 0.1, delay: 0, options: [.curveLinear], animations: {
                        timeLabel.center = CGPoint(x: labelX, y: 10)
                    })
                }
            }
        }

        // 스크롤 자동 조정 (playhead가 화면 중앙에 오도록)
        if !context.coordinator.isUserScrolling {
            let targetOffsetX = playheadPosition - screenWidth / 2
            let maxOffsetX = max(0, containerWidth - screenWidth)
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
        var playheadView: PlayheadUIView?
        var timelineView: UIView?
        var timelineHostingController: UIHostingController<AnyView>?
        var rulerView: TimeRulerView?
        var timeLabel: UILabel?
        var isUserScrolling = false
        var isSeeking = false  // seek 중인지 추적

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

// MARK: - Time Ruler View (시간 눈금자)
private class TimeRulerView: UIView {
    var duration: Double = 0
    var pixelsPerSecond: CGFloat = 50
    var handleWidth: CGFloat = 12
    var onSeek: ((Double) -> Void)?
    private let timeFont = UIFont.systemFont(ofSize: 14, weight: .regular)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        // handleWidth 오프셋 제거
        let adjustedX = location.x - handleWidth
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

        // 1초 간격으로 눈금 그리기
        let totalSeconds = Int(ceil(duration))
        for second in 0...totalSeconds {
            // handleWidth만큼 오프셋 추가
            let xPosition = CGFloat(second) * pixelsPerSecond + handleWidth

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

// MARK: - Playhead UIView (네이티브)
private class PlayheadUIView: UIView {
    // 눈금자 높이와 그 아래 gap 높이 (삼각형은 gap에, 선은 그 아래에서 시작)
    var rulerHeight: CGFloat = 20
    var gapHeight: CGFloat = 16

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
                    .frame(width: 80, height: 80)
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
    let seekTarget: Double?
    let selectedFilter: VideoFilter?
    let onTimeUpdate: (Double) -> Void
    let onDurationUpdate: (Double) -> Void
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
            onPlaybackEnded: onPlaybackEnded
        )
    }

    final class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var timeObserver: Any?
        var boundaryObserver: Any?
        var currentAVAsset: AVAsset?
        var lastAppliedFilter: VideoFilter?
        var currentPreProcessedURL: URL?  // 현재 로드된 전처리 비디오 URL
        let onTimeUpdate: (Double) -> Void
        let onDurationUpdate: (Double) -> Void
        let onPlaybackEnded: () -> Void

        init(
            onTimeUpdate: @escaping (Double) -> Void,
            onDurationUpdate: @escaping (Double) -> Void,
            onPlaybackEnded: @escaping () -> Void
        ) {
            self.onTimeUpdate = onTimeUpdate
            self.onDurationUpdate = onDurationUpdate
            self.onPlaybackEnded = onPlaybackEnded
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

            // Duration 업데이트 및 경계 옵저버 등록
            Task { [weak self] in
                guard let self else { return }
                if let duration = try? await avAsset.load(.duration) {
                    let durationSeconds = duration.seconds
                    if durationSeconds.isFinite {
                        await MainActor.run {
                            self.onDurationUpdate(durationSeconds)
                            self.installBoundaryObserver(at: duration)
                        }
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
                    if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite {
                        self.onTimeUpdate(min(currentTime, duration))
                    } else {
                        self.onTimeUpdate(currentTime)
                    }
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
        }

        func pause() {
            player?.pause()
        }

        func seekToTime(_ time: Double) {
            guard let player = player else { return }
            let targetTime = CMTime(seconds: time, preferredTimescale: 600)
            // 즉시 이동하도록 completion handler 사용
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
                if completed {
                    // seek가 완료되면 즉시 시간 업데이트
                    DispatchQueue.main.async {
                        self?.onTimeUpdate(time)
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
            if let boundaryObserver = boundaryObserver {
                player?.removeTimeObserver(boundaryObserver)
            }
            player?.pause()
        }
    }
}

