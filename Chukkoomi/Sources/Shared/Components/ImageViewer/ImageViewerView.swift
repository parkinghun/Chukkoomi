//
//  ImageViewerView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

// MARK: - View
struct ImageViewerView: View {
    let store: StoreOf<ImageViewerFeature>

    // MARK: - Gesture Handlers (복잡도 분리)

    // 제스처 방향 결정 (페이징 감도 개선)
    private func determineGestureDirection(translation: CGSize) -> Bool? {
        // 최소 이동 거리 임계값
        let minimumDistance: CGFloat = 10

        let distance = sqrt(translation.width * translation.width + translation.height * translation.height)
        guard distance > minimumDistance else { return nil }  // 아직 판단 불가

        // Angle 기반 방향 판단 (45도 = 0.785 rad)
        let angle = atan2(abs(translation.height), abs(translation.width))
        let verticalThreshold = CGFloat.pi / 4  // 45도

        return angle > verticalThreshold  // true = vertical, false = horizontal
    }

    private func handlePinchChanged(scale: CGFloat, anchor: CGPoint) {
        store.send(.pinchChanged(scale: scale, anchor: anchor))
    }

    private func handlePinchEnded() {
        withAnimation(.spring(response: 0.3)) {
            _ = store.send(.pinchEnded)
        }
    }

    private func handlePanChanged(_ translation: CGSize) {
        if store.scale > 1.2 {
            store.send(.dragChanged(translation))
        } else {
            // 방향 결정 (최소 거리 + angle 기반)
            guard let isVertical = determineGestureDirection(translation: translation) else {
                return  // 아직 최소 거리에 도달하지 않음
            }

            if isVertical {
                store.send(.dismissGestureChanged(translation.height))
            } else if store.isMultiImage {
                store.send(.swipeChanged(translation.width))
            }
        }
    }

    private func handlePanEnded(_ velocity: CGSize) {
        if store.scale > 1.2 {
            // 관성은 60FPS 루프에서 자체적으로 처리하므로 애니메이션 불필요
            store.send(.dragEnded(velocity: velocity))
        } else {
            // Velocity 기반 방향 판단
            let isVertical = abs(velocity.height) > abs(velocity.width)

            if isVertical {
                withAnimation(.spring(response: 0.3)) {
                    _ = store.send(.dismissGestureEnded(velocity: velocity.height))
                }
            } else if store.isMultiImage {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    _ = store.send(.swipeEnded(velocity.width * 0.5))
                }
            }
        }
    }

    private func handleDoubleTap(at location: CGPoint) {
        withAnimation(.spring(response: 0.3)) {
            _ = store.send(.doubleTapped(at: location))
        }
    }

    // MARK: - Computed Properties

    private var effectiveScale: CGFloat {
        store.scale * (1 - store.dismissProgress * 0.1)
    }

    private var effectiveOffsetX: CGFloat {
        store.offset.width + store.panOffset.width + store.dragOffset
    }

    private var effectiveOffsetY: CGFloat {
        store.offset.height + store.panOffset.height + store.dismissTranslation
    }

    private var backgroundColor: Color {
//        Color.black.opacity(1 - store.dismissProgress)
        Color.black.opacity(1.0 - Double(store.dismissProgress))
    }

    var body: some View {
        ZStack {
            // 배경 레이어 (dismissProgress에 따라 투명도 조절)
            backgroundColor
                .ignoresSafeArea()

            // 컨텐츠 레이어
            GeometryReader { geometry in
                // 베이스 레이어
                Group {
                    if let image = store.currentImage {
                        ZoomableImageView(
                            image: image,
                            viewSize: geometry.size,
                            onPinchChanged: handlePinchChanged,
                            onPinchEnded: handlePinchEnded,
                            onPanChanged: handlePanChanged,
                            onPanEnded: handlePanEnded,
                            onDoubleTap: handleDoubleTap
                        )
                        .scaleEffect(effectiveScale)
                        .offset(x: effectiveOffsetX, y: effectiveOffsetY)
                    } else {
                        // 이미지 로드 실패
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.white)

                        Text("이미지를 불러올 수 없습니다")
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            // 오버레이: 닫기 버튼 (오른쪽 상단)
            .overlay(alignment: .topTrailing) {
                Button {
                    store.send(.dismissTapped)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 36, height: 36)
                        )
                }
                .padding(.trailing, 20)
                .padding(.top, geometry.safeAreaInsets.top + 50)  // SafeArea 고려하여 적당한 위치에 배치
            }
            // 오버레이: 페이지 인디케이터 (왼쪽 상단)
            .overlay(alignment: .topLeading) {
                if store.isMultiImage {
                    Text("\(store.currentIndex + 1) / \(store.images.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                        .padding(.leading, 20)
                        .padding(.top, geometry.safeAreaInsets.top + 50)  // SafeArea 고려하여 적당한 위치에 배치
                }
            }
            // 오버레이: 도트 인디케이터 (하단)
            .overlay(alignment: .bottom) {
                if store.isMultiImage {
                    HStack(spacing: 8) {
                        ForEach(0..<store.images.count, id: \.self) { index in
                            Circle()
                                .fill(index == store.currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        _ = store.send(.goToPage(index))
                                    }
                                }
                        }
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)  // SafeArea 고려
                }
            }
            }  // GeometryReader 닫기
        }  // ZStack 닫기
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .transition(.opacity)
    }
}

// MARK: - ZoomableImageView (UIKit 제스처만 담당)
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let viewSize: CGSize

    let onPinchChanged: (CGFloat, CGPoint) -> Void
    let onPinchEnded: () -> Void
    let onPanChanged: (CGSize) -> Void
    let onPanEnded: (CGSize) -> Void
    let onDoubleTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ZoomableImageUIView {
        let view = ZoomableImageUIView(
            image: image,
            coordinator: context.coordinator
        )
        print("[ImageViewer] makeUIView called")
        return view
    }

    func updateUIView(_ uiView: ZoomableImageUIView, context: Context) {
        // Coordinator의 parent를 업데이트하여 최신 콜백 사용
        context.coordinator.parent = self
        uiView.updateImage(image)
        print("[ImageViewer] updateUIView called - frame: \(uiView.frame)")
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ZoomableImageUIView, context: Context) -> CGSize? {
        let size = CGSize(width: proposal.width ?? viewSize.width, height: proposal.height ?? viewSize.height)
        print("[ImageViewer] sizeThatFits: \(size)")
        return size
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject {
        var parent: ZoomableImageView
        
        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }
        
        func pinchChanged(scale: CGFloat, anchor: CGPoint) {
            print("[Coordinator] pinchChanged: scale=\(scale), anchor=\(anchor)")
            parent.onPinchChanged(scale, anchor)
        }

        func pinchEnded() {
            print("[Coordinator] pinchEnded")
            parent.onPinchEnded()
        }

        func panChanged(translation: CGSize) {
            print("[Coordinator] panChanged: \(translation)")
            parent.onPanChanged(translation)
        }

        func panEnded(velocity: CGSize) {
            print("[Coordinator] panEnded: velocity=\(velocity)")
            parent.onPanEnded(velocity)
        }

        func doubleTap(at location: CGPoint) {
            print("[Coordinator] doubleTap at: \(location)")
            parent.onDoubleTap(location)
        }
    }
}

// MARK: - ZoomableImageUIView
class ZoomableImageUIView: UIView {
    private let imageView: UIImageView
    private var lastPinchScale: CGFloat = 1.0
    private var lastPanTranslation: CGPoint = .zero
    private weak var coordinator: ZoomableImageView.Coordinator?
    
    init(image: UIImage, coordinator: ZoomableImageView.Coordinator) {
        self.coordinator = coordinator
        self.imageView = UIImageView(image: image)
        self.imageView.contentMode = .scaleAspectFit
        
        super.init(frame: .zero)
        
        // 터치 이벤트 수신 활성화
        isUserInteractionEnabled = true
        clipsToBounds = true
        backgroundColor = .clear
        
        // 이미지뷰 설정
        imageView.isUserInteractionEnabled = false  // 제스처는 부모 뷰에서 처리
        
        addSubview(imageView)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        print("[ImageViewer] Layout: frame=\(frame), bounds=\(bounds)")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        print("[ImageViewer] HitTest at \(point) -> \(result?.description ?? "nil")")
        return result
    }

    private func setupGestures() {
        // 핀치 제스처
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        // 더블 탭 제스처 (Pan보다 먼저 추가)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        // 싱글 탭 제스처 (더블 탭과 구분)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)  // 더블 탭이 실패해야 싱글 탭 인식
        addGestureRecognizer(singleTap)

        // 팬 제스처
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1  // 1개 손가락만 (2개는 pinch용)
        pan.require(toFail: doubleTap)  // 더블 탭이 아닐 때만 pan
        addGestureRecognizer(pan)

        print("[ImageViewer] Gestures setup complete")
    }
    
    func updateImage(_ image: UIImage) {
        imageView.image = image
    }

    // MARK: - Gesture Handlers
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        print("[ImageViewer] Pinch gesture: \(gesture.state.rawValue)")
        switch gesture.state {
        case .began:
            lastPinchScale = 1.0

        case .changed:
            // 핀치 중심점 (뷰 중심 기준 좌표로 변환)
            let location = gesture.location(in: self)
            let centerX = bounds.width / 2
            let centerY = bounds.height / 2
            let anchorFromCenter = CGPoint(
                x: location.x - centerX,
                y: location.y - centerY
            )
            
            coordinator?.pinchChanged(scale: gesture.scale, anchor: anchorFromCenter)
            
        case .ended, .cancelled:
            lastPinchScale = 1.0
            coordinator?.pinchEnded()
            
        default:
            break
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        print("[ImageViewer] Pan gesture: \(gesture.state.rawValue)")
        switch gesture.state {
        case .began:
            lastPanTranslation = .zero

        case .changed:
            let currentTranslation = gesture.translation(in: self)

            // 델타를 전달
            coordinator?.panChanged(translation: CGSize(width: currentTranslation.x, height: currentTranslation.y))

            // 현재 translation 저장
            lastPanTranslation = currentTranslation

        case .ended, .cancelled:
            let velocity = gesture.velocity(in: self)
            coordinator?.panEnded(velocity: CGSize(width: velocity.x, height: velocity.y))
            lastPanTranslation = .zero

        default:
            break
        }
    }
    
    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        print("[ImageViewer] Single tap detected (ignored)")
        // 싱글 탭은 무시 (UI 토글 등에 사용 가능)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        print("[ImageViewer] Double tap detected!")
        let location = gesture.location(in: self)
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        let tapFromCenter = CGPoint(
            x: location.x - centerX,
            y: location.y - centerY
        )
        coordinator?.doubleTap(at: tapFromCenter)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ZoomableImageUIView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // 핀치와 팬만 동시 인식 허용
        let isPinch = gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer
        let isPan = gestureRecognizer is UIPanGestureRecognizer || otherGestureRecognizer is UIPanGestureRecognizer

        // 핀치 + 팬은 동시 인식
        if isPinch && isPan {
            return true
        }

        // 나머지는 순차적으로 인식
        return false
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        print("[ImageViewer] Gesture should begin: \(type(of: gestureRecognizer))")
        return true
    }
}

#Preview("Single Image") {
    ImageViewerView(
        store: Store(
            initialState: ImageViewerFeature.State(image: UIImage(systemName: "photo.fill")!)
        ) {
            ImageViewerFeature()
        }
    )
}

#Preview("Multi Images") {
    ImageViewerView(
        store: Store(
            initialState: ImageViewerFeature.State(images: [
                UIImage(systemName: "photo.fill")!,
                UIImage(systemName: "photo.circle")!,
                UIImage(systemName: "photo.stack")!
            ])
        ) {
            ImageViewerFeature()
        }
    )
}
