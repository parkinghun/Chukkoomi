//
//  ImageViewerFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/22/25.
//

import SwiftUI
import ComposableArchitecture

// MARK: - Feature
@Reducer
struct ImageViewerFeature {

    // MARK: - Dependencies

    private enum CancelID {
        case inertia
    }

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var images: [UIImage]
        var currentIndex: Int = 0

        // 줌/드래그 상태
        var scale: CGFloat = 1.0
        var lastScale: CGFloat = 1.0
        var offset: CGSize = .zero
        var lastOffset: CGSize = .zero
        var panOffset: CGSize = .zero  // 드래그 중 임시 오프셋 (부드러운 이동용)
        var pinchAnchor: CGPoint?  // Pinch 시작 시 고정된 anchor (이미지 공간 좌표)

        // 스와이프 상태
        var dragOffset: CGFloat = 0

        // 제스처 방향 (페이징 감도 개선)
        enum GestureDirection {
            case none
            case vertical    // Dismiss 또는 수직 드래그
            case horizontal  // 이미지 스와이프
        }
        var gestureDirection: GestureDirection = .none

        // 애니메이션 상태
        var isAnimating: Bool = false  // 더블탭 throttle용

        // Drag-to-dismiss 상태
        var dismissProgress: CGFloat = 0  // 0~1 (0=정상, 1=닫기)
        var dismissTranslation: CGFloat = 0  // 수직 드래그 거리

        // Inertia (관성) 상태
        var inertiaVelocity: CGSize = .zero  // 현재 관성 속도
        var isInertiaActive: Bool = false  // 관성 스크롤 진행 중

        let minScale: CGFloat = 1.0
        let maxScale: CGFloat = 4.0

        var currentImage: UIImage? {
            guard currentIndex >= 0 && currentIndex < images.count else { return nil }
            return images[currentIndex]
        }

        var isMultiImage: Bool {
            images.count > 1
        }

        // 단일 UIImage 초기화
        init(image: UIImage) {
            self.images = [image]
            self.currentIndex = 0
        }

        // 다중 UIImage 초기화
        init(images: [UIImage], initialIndex: Int = 0) {
            self.images = images
            self.currentIndex = min(max(0, initialIndex), max(0, images.count - 1))
        }

        // 단일 Data 초기화
        init(imageData: Data) {
            if let image = UIImage(data: imageData) {
                self.images = [image]
            } else {
                self.images = []
            }
            self.currentIndex = 0
        }

        // 다중 Data 초기화
        init(imageDatas: [Data], initialIndex: Int = 0) {
            self.images = imageDatas.compactMap { UIImage(data: $0) }
            self.currentIndex = min(max(0, initialIndex), max(0, self.images.count - 1))
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        // 줌 제스처 (앵커 포인트 기반)
        case pinchChanged(scale: CGFloat, anchor: CGPoint)
        case pinchEnded

        // 드래그 제스처 (확대 시 패닝)
        case dragChanged(CGSize)
        case dragEnded(velocity: CGSize)

        // 스와이프 제스처 (이미지 전환)
        case swipeChanged(CGFloat)
        case swipeEnded(CGFloat)

        // 더블 탭 (탭 위치 기준 확대)
        case doubleTapped(at: CGPoint)
        case animationCompleted  // 애니메이션 완료 시 플래그 해제

        // Drag-to-dismiss (아래로 드래그하면 닫힘)
        case dismissGestureChanged(CGFloat)  // 수직 translation
        case dismissGestureEnded(velocity: CGFloat)  // 수직 velocity

        // Inertia (관성) 스크롤
        case inertiaUpdate  // 매 프레임 호출 (60FPS)
        case inertiaStop  // 관성 종료

        // 페이지 이동
        case goToPage(Int)

        // 닫기
        case dismissTapped

        // Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            case dismiss
        }
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .pinchChanged(scale: gestureScale, anchor: viewAnchor):
                // Pinch 시작 시 anchor를 이미지 공간 좌표로 변환하여 고정
                if state.pinchAnchor == nil {
                    // 첫 프레임: anchor를 이미지 공간 좌표로 변환
                    let imageAnchor = CGPoint(
                        x: (viewAnchor.x - state.offset.width) / state.scale,
                        y: (viewAnchor.y - state.offset.height) / state.scale
                    )
                    state.pinchAnchor = imageAnchor
                }

                guard let imageAnchor = state.pinchAnchor else { return .none }

                // 새로운 스케일 계산
                let delta = gestureScale / state.lastScale
                state.lastScale = gestureScale
                let newScale = min(max(state.scale * delta, state.minScale), state.maxScale)

                print("[Feature] pinchChanged: gestureScale=\(gestureScale), delta=\(delta), oldScale=\(state.scale), newScale=\(newScale)")

                // 고정된 이미지 anchor가 화면에서 같은 위치에 있도록 offset 계산
                // viewAnchor = imageAnchor * newScale + newOffset
                // -> newOffset = viewAnchor - imageAnchor * newScale
                if state.scale != newScale {
                    let newOffsetX = viewAnchor.x - imageAnchor.x * newScale
                    let newOffsetY = viewAnchor.y - imageAnchor.y * newScale

                    state.offset = CGSize(width: newOffsetX, height: newOffsetY)
                    state.scale = newScale
                    print("[Feature] Updated: scale=\(state.scale), offset=\(state.offset)")
                }

                // Clamp 전 offset 저장
                let offsetBeforeClamp = state.offset

                // 축소 시 offset 보정
                clampOffset(&state)

                // Clamp로 인해 offset이 변경되었다면 anchor 보정
                if state.offset != offsetBeforeClamp {
                    // Clamp된 offset 기준으로 anchor 재계산 (이미지 공간 좌표)
                    let correctedAnchor = CGPoint(
                        x: (viewAnchor.x - state.offset.width) / state.scale,
                        y: (viewAnchor.y - state.offset.height) / state.scale
                    )
                    state.pinchAnchor = correctedAnchor
                }

                return .none

            case .pinchEnded:
                state.lastScale = 1.0
                state.panOffset = .zero  // 임시 오프셋 초기화
                state.pinchAnchor = nil  // Anchor 초기화

                // Scale이 1.0에 매우 가까우면 (1.05 미만) 1.0으로 스냅
                if state.scale < 1.05 {
                    resetZoomState(&state)  // 완전 초기화
                } else if state.scale < state.minScale {
                    // 최소 스케일보다 작으면 원래대로
                    resetZoomState(&state)
                } else {
                    // offset 보정
                    clampOffset(&state)
                    state.lastOffset = state.offset
                }
                return .none

            case let .dragChanged(translation):
                // 드래그 시작 시 관성 중단
                if state.isInertiaActive {
                    state.isInertiaActive = false
                    state.inertiaVelocity = .zero
                }

                if state.scale > 1.2 {  // 1.2 초과일 때만 팬 (스와이프/dismiss와 구분)
                    // Scale 보정: log 기반 (scale 커질수록 약간만 느려짐)
                    // Photos 앱 방식: scale이 커져도 빠른 반응 유지
//                    let dampingFactor = 1.0 / log2(state.scale + 1)  // scale 1→1, 2→1.58, 4→1.26
                    
                    // Improved drag sensitivity: linear-soft damping
                    // scale 1.0 → factor 1.0 (fast)
                    // scale 2.0 → factor 0.7
                    // scale 4.0 → factor 0.45
                    let dampingFactor: CGFloat = {
                        let s = state.scale
                        return max(0.45, 1.0 - (s - 1.0) * 0.25)
                    }()
                    
                    let effectiveTranslation = CGSize(
                        width: translation.width * dampingFactor,
                        height: translation.height * dampingFactor
                    )
                    state.panOffset = effectiveTranslation
                }
                return state.isInertiaActive ? .cancel(id: CancelID.inertia) : .none

            case let .dragEnded(velocity: velocity):
                // 임시 오프셋을 최종 오프셋에 반영
                state.offset = CGSize(
                    width: state.lastOffset.width + state.panOffset.width,
                    height: state.lastOffset.height + state.panOffset.height
                )
                state.panOffset = .zero
                state.lastOffset = state.offset

                // Velocity 기반 60FPS 관성 시작
                // dragChanged와 동일한 log 기반 보정
                let dampingFactor = 1.0 / log2(state.scale + 1)
                let effectiveVelocity = CGSize(
                    width: velocity.width * dampingFactor,
                    height: velocity.height * dampingFactor
                )

                // 최소 velocity 임계값: 너무 느리면 관성 스킵
                let velocityThreshold: CGFloat = 300 /*100*/
                let velocityMagnitude = sqrt(effectiveVelocity.width * effectiveVelocity.width +
                                            effectiveVelocity.height * effectiveVelocity.height)

                if velocityMagnitude > velocityThreshold {
                    state.inertiaVelocity = effectiveVelocity
                    state.isInertiaActive = true

                    // 60FPS 타이머 시작 (cancellable)
                    return .run { send in
                        while true {
                            try await Task.sleep(for: .milliseconds(16))  // ~60FPS
                            await send(.inertiaUpdate)
                        }
                    }
                    .cancellable(id: CancelID.inertia)
                } else {
                    // 관성 없이 즉시 종료
                    clampOffset(&state)
                    state.lastOffset = state.offset
                    return .none
                }

            case .inertiaUpdate:
                guard state.isInertiaActive else { return .send(.inertiaStop) }

                // Velocity 감속 (매 프레임 3% 감소 - Photos 앱 스타일)
                let decayRate: CGFloat = 0.93
                state.inertiaVelocity.width *= decayRate
                state.inertiaVelocity.height *= decayRate

                // Offset 업데이트 (velocity / 60)
                state.offset.width += state.inertiaVelocity.width / 60
                state.offset.height += state.inertiaVelocity.height / 60

                // 경계 체크
                clampOffset(&state)
                // Reset velocity if clamped (prevents infinite sliding)
                if state.offset.width == -((UIScreen.main.bounds.width * state.scale - UIScreen.main.bounds.width) / 2) ||
                   state.offset.width ==  ((UIScreen.main.bounds.width * state.scale - UIScreen.main.bounds.width) / 2) {
                    state.inertiaVelocity.width = 0
                }
                if state.offset.height == -((UIScreen.main.bounds.height * state.scale - UIScreen.main.bounds.height) / 2) ||
                   state.offset.height ==  ((UIScreen.main.bounds.height * state.scale - UIScreen.main.bounds.height) / 2) {
                    state.inertiaVelocity.height = 0
                }

                // 정지 조건: velocity가 매우 작아지면 종료
                let velocityMagnitude = sqrt(state.inertiaVelocity.width * state.inertiaVelocity.width +
                                            state.inertiaVelocity.height * state.inertiaVelocity.height)
                if velocityMagnitude < 50 {
                    return .send(.inertiaStop)
                }

                return .none

            case .inertiaStop:
                state.isInertiaActive = false
                state.inertiaVelocity = .zero
                state.lastOffset = state.offset
                return .cancel(id: CancelID.inertia)

            case let .swipeChanged(translation):
                // 확대 중이면 스와이프 무시
                guard state.scale <= 1.0 else { return .none }
                state.dragOffset = translation
                return .none

            case let .swipeEnded(predictedEndTranslation):
                // 확대 중이면 스와이프 무시
                guard state.scale <= 1.0 else { return .none }

                let threshold: CGFloat = 100

                if predictedEndTranslation < -threshold && state.currentIndex < state.images.count - 1 {
                    // 왼쪽으로 스와이프 -> 다음 이미지
                    state.currentIndex += 1
                    resetZoomState(&state)
                } else if predictedEndTranslation > threshold && state.currentIndex > 0 {
                    // 오른쪽으로 스와이프 -> 이전 이미지
                    state.currentIndex -= 1
                    resetZoomState(&state)
                }

                state.dragOffset = 0
                return .none

            case let .doubleTapped(at: tapPoint):
                // 애니메이션 중에는 무시 (throttle)
                guard !state.isAnimating else { return .none }

                state.isAnimating = true
                state.panOffset = .zero  // 임시 오프셋 초기화

                // Scale 레벨링: 1x → 2.5x → 1x (Photos 방식)
                var targetScale: CGFloat

                // 현재 scale에서 다음 레벨 결정
                if state.scale < 1.5 {
                    // 1.0 근처 → 2.5로 확대
                    targetScale = 2.5
                } else {
                    // 1.5 이상 → 1.0으로 초기화
                    resetZoomState(&state)
                    // 애니메이션 종료 후 플래그 해제
                    return .run { send in
                        try await Task.sleep(for: .milliseconds(300))
                        await send(.animationCompleted)
                    }
                }

                // Anchor 좌표 정규화 (현재 transform 기준)
                // tapPoint는 뷰 중심 기준 좌표
                // 현재 offset과 scale이 적용된 상태에서의 이미지 좌표로 변환
                let imagePoint = CGPoint(
                    x: (tapPoint.x - state.offset.width) / state.scale,
                    y: (tapPoint.y - state.offset.height) / state.scale
                )

                // 새로운 scale 적용 후 해당 포인트가 화면에서 같은 위치에 있도록
                let newOffsetX = tapPoint.x - imagePoint.x * targetScale
                let newOffsetY = tapPoint.y - imagePoint.y * targetScale

                state.offset = CGSize(width: newOffsetX, height: newOffsetY)
                state.scale = targetScale

                // offset 보정 (경계 체크)
                clampOffset(&state)
                state.lastOffset = state.offset

                // 애니메이션 종료 후 플래그 해제 (0.3초는 withAnimation의 duration)
                return .run { send in
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.animationCompleted)
                }

            case .animationCompleted:
                state.isAnimating = false
                return .none

            case let .goToPage(index):
                guard index >= 0 && index < state.images.count else { return .none }
                state.currentIndex = index
                resetZoomState(&state)
                return .none

            case let .dismissGestureChanged(translation):
                // scale이 1.2 이하일 때만 dismiss 가능
                guard state.scale <= 1.2 else { return .none }

                state.dismissTranslation = translation

                // dismissProgress 계산: 200pt 이동하면 1.0
                let threshold: CGFloat = 200
                state.dismissProgress = min(max(abs(translation) / threshold, 0), 1)

                return .none

            case let .dismissGestureEnded(velocity: velocity):
                // Velocity나 거리 기준으로 닫기 판단
                let velocityThreshold: CGFloat = 1000  // pt/s
                let progressThreshold: CGFloat = 0.5

                let shouldDismiss = abs(velocity) > velocityThreshold || state.dismissProgress > progressThreshold

                if shouldDismiss {
                    // 닫기
                    return .send(.delegate(.dismiss))
                } else {
                    // 취소: 원래대로
                    state.dismissProgress = 0
                    state.dismissTranslation = 0
                    return .none
                }

            case .dismissTapped:
                return .send(.delegate(.dismiss))

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Helper Methods

    /// offset을 이미지 실제 렌더링 크기 기준으로 clamp
    private func clampOffset(_ state: inout State) {
        // scale이 1이면 offset은 0이어야 함
        if state.scale <= 1.0 {
            state.offset = .zero
            return
        }

        guard let image = state.currentImage else { return }

        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        // 이미지의 실제 렌더링 크기 계산 (scaleAspectFit)
        let imageAspect = image.size.width / image.size.height
        let screenAspect = screenWidth / screenHeight

        var renderWidth: CGFloat
        var renderHeight: CGFloat

        if imageAspect > screenAspect {
            // 이미지가 더 넓음 → 가로 기준 맞춤
            renderWidth = screenWidth
            renderHeight = screenWidth / imageAspect
        } else {
            // 이미지가 더 높음 → 세로 기준 맞춤
            renderHeight = screenHeight
            renderWidth = screenHeight * imageAspect
        }

        // scale 적용 후 크기
        let scaledWidth = renderWidth * state.scale
        let scaledHeight = renderHeight * state.scale

        // 이동 가능한 최대 범위 (확대된 이미지가 화면을 벗어난 만큼)
        let maxOffsetX = max(0, (scaledWidth - screenWidth) / 2)
        let maxOffsetY = max(0, (scaledHeight - screenHeight) / 2)

        state.offset.width = min(max(state.offset.width, -maxOffsetX), maxOffsetX)
        state.offset.height = min(max(state.offset.height, -maxOffsetY), maxOffsetY)
    }

    /// 줌 상태 초기화
    private func resetZoomState(_ state: inout State) {
        state.scale = 1.0
        state.lastScale = 1.0
        state.offset = .zero
        state.lastOffset = .zero
        state.panOffset = .zero
        state.pinchAnchor = nil
    }
}
