//
//  StickerOverlayView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

struct StickerOverlayView: View {
    let sticker: EditPhotoFeature.StickerOverlay
    let isSelected: Bool
    let imageSize: CGSize
    let onTransformChanged: (CGPoint, CGFloat, Angle) -> Void
    let onTap: () -> Void
    let onDelete: () -> Void

    // Gesture state
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

    var body: some View {
        let baseStickerSize = imageSize.width * 0.2
        let finalScale = currentScale * gestureScale

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
                    .frame(width: baseStickerSize + 8, height: baseStickerSize + 8)
            }

            // Delete Button
            if isSelected {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
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
        .scaleEffect(finalScale)
        .rotationEffect(currentRotation + gestureRotation)
        .position(
            x: (currentPosition.x + dragOffset.width / imageSize.width) * imageSize.width,
            y: (currentPosition.y + dragOffset.height / imageSize.height) * imageSize.height
        )
        .gesture(
            SimultaneousGesture(
                // Drag Gesture
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let normalizedX = currentPosition.x + value.translation.width / imageSize.width
                        let normalizedY = currentPosition.y + value.translation.height / imageSize.height

                        // Clamp to 0.0~1.0
                        let clampedX = min(max(normalizedX, 0.0), 1.0)
                        let clampedY = min(max(normalizedY, 0.0), 1.0)

                        currentPosition = CGPoint(x: clampedX, y: clampedY)
                        onTransformChanged(currentPosition, currentScale, currentRotation)
                    },

                // Scale + Rotation Gesture
                MagnificationGesture()
                    .updating($gestureScale) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        currentScale *= value
                        onTransformChanged(currentPosition, currentScale, currentRotation)
                    }
                    .simultaneously(with:
                        RotationGesture()
                            .updating($gestureRotation) { value, state, _ in
                                state = value
                            }
                            .onEnded { value in
                                currentRotation += value
                                onTransformChanged(currentPosition, currentScale, currentRotation)
                            }
                    )
            )
        )
        .onTapGesture {
            onTap()
        }
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
