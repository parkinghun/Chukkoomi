//
//  StickerOverlayView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

/// 스티커 오버레이 뷰
/// - 드래그, 확대/축소, 회전 제스처 지원
/// - 선택 시 테두리 및 삭제 버튼 표시
struct StickerOverlayView: View {
    let sticker: EditPhotoFeature.StickerOverlay
    let isSelected: Bool
    let imageSize: CGSize
    let onTransformChanged: (CGPoint, CGFloat, Angle) -> Void
    let onTap: () -> Void
    let onDelete: () -> Void

    // MARK: - Constants

    /// 기본 스티커 크기 (이미지 너비의 비율)
    private static let stickerSizeRatio: CGFloat = 0.2
    /// 선택 테두리 패딩
    private static let selectionBorderPadding: CGFloat = 8
    /// 삭제 버튼 크기
    private static let deleteButtonSize: CGFloat = 24

    // MARK: - Gesture State

    @State private var currentPosition: CGPoint
    @State private var currentScale: CGFloat
    @State private var currentRotation: Angle

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureRotation: Angle = .zero

    init(
        sticker: EditPhotoFeature.StickerOverlay,
        isSelected: Bool,
        imageSize: CGSize,
        onTransformChanged: @escaping (CGPoint, CGFloat, Angle) -> Void,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.sticker = sticker
        self.isSelected = isSelected
        self.imageSize = imageSize
        self.onTransformChanged = onTransformChanged
        self.onTap = onTap
        self.onDelete = onDelete

        // Initialize state
        _currentPosition = State(initialValue: sticker.position)
        _currentScale = State(initialValue: sticker.scale)
        _currentRotation = State(initialValue: sticker.rotation)
    }

    // MARK: - Helper Functions

    /// 정규화된 좌표(0.0~1.0)를 픽셀 좌표로 변환
    private func denormalizePosition(_ normalized: CGPoint, offset: CGSize = .zero) -> CGPoint {
        let normalizedX = normalized.x + offset.width / imageSize.width
        let normalizedY = normalized.y + offset.height / imageSize.height

        return CGPoint(
            x: normalizedX * imageSize.width,
            y: normalizedY * imageSize.height
        )
    }

    /// 픽셀 오프셋을 정규화된 좌표로 변환하고 0.0~1.0 범위로 제한
    private func normalizeAndClamp(position: CGPoint, translation: CGSize) -> CGPoint {
        let normalizedX = position.x + translation.width / imageSize.width
        let normalizedY = position.y + translation.height / imageSize.height

        return CGPoint(
            x: min(max(normalizedX, 0.0), 1.0),
            y: min(max(normalizedY, 0.0), 1.0)
        )
    }

    // MARK: - Computed Properties

    /// 스티커 기본 크기
    private var baseStickerSize: CGFloat {
        imageSize.width * Self.stickerSizeRatio
    }

    /// 최종 스케일 (현재 스케일 × 제스처 스케일)
    private var finalScale: CGFloat {
        currentScale * gestureScale
    }

    /// 드래그 제스처
    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                currentPosition = normalizeAndClamp(
                    position: currentPosition,
                    translation: value.translation
                )
                onTransformChanged(currentPosition, currentScale, currentRotation)
            }
    }

    /// 확대/축소 제스처
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                currentScale *= value
                onTransformChanged(currentPosition, currentScale, currentRotation)
            }
    }

    /// 회전 제스처
    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($gestureRotation) { value, state, _ in
                state = value
            }
            .onEnded { value in
                currentRotation += value
                onTransformChanged(currentPosition, currentScale, currentRotation)
            }
    }

    /// 드래그 + 확대/축소 + 회전을 동시에 처리하는 복합 제스처
    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            dragGesture,
            magnificationGesture.simultaneously(with: rotationGesture)
        )
    }

    // MARK: - Body

    var body: some View {
        let pixelPosition = denormalizePosition(currentPosition, offset: dragOffset)

        ZStack {
            // Sticker Image
            Image(sticker.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: baseStickerSize, height: baseStickerSize)

            // Selection Border
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(
                        width: baseStickerSize + Self.selectionBorderPadding,
                        height: baseStickerSize + Self.selectionBorderPadding
                    )
            }

            // Delete Button
            if isSelected {
                deleteButton
            }
        }
        .scaleEffect(finalScale)
        .rotationEffect(currentRotation + gestureRotation)
        .position(pixelPosition)
        .gesture(combinedGesture)
        .onTapGesture {
            onTap()
        }
    }

    /// 삭제 버튼
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: Self.deleteButtonSize))
                .foregroundColor(.red)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                )
        }
        .offset(x: baseStickerSize / 2, y: -baseStickerSize / 2)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)

        StickerOverlayView(
            sticker: EditPhotoFeature.StickerOverlay(
                imageName: "sticker_1",
                position: CGPoint(x: 0.5, y: 0.5)
            ),
            isSelected: true,
            imageSize: CGSize(width: 400, height: 300),
            onTransformChanged: { _, _, _ in },
            onTap: {},
            onDelete: {}
        )
    }
    .frame(width: 400, height: 300)
}
