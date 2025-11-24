//
//  CropOverlayView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

struct CropOverlayView: View {
    let cropRect: CGRect  // Normalized (0.0~1.0)
    let imageSize: CGSize
    let onCropRectChanged: (CGRect) -> Void

    @State private var startCropRect: CGRect = .zero
    @State private var dragType: DragType = .none

    enum DragType {
        case none
        case move
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    var body: some View {
        GeometryReader { geometry in
            let actualRect = CGRect(
                x: cropRect.origin.x * geometry.size.width,
                y: cropRect.origin.y * geometry.size.height,
                width: cropRect.width * geometry.size.width,
                height: cropRect.height * geometry.size.height
            )

            ZStack {
                // 어두운 오버레이 (자를 영역 제외)
                Color.black.opacity(0.5)
                    .mask {
                        ZStack {
                            Rectangle()
                                .fill(Color.white)
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: actualRect.width, height: actualRect.height)
                                .position(
                                    x: actualRect.midX,
                                    y: actualRect.midY
                                )
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                    .allowsHitTesting(false)

                // Crop 영역 테두리
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: actualRect.width, height: actualRect.height)
                    .position(
                        x: actualRect.midX,
                        y: actualRect.midY
                    )
                    .allowsHitTesting(false)

                // 그리드 라인 (3x3)
                Path { path in
                    // 세로 라인 2개
                    let thirdWidth = actualRect.width / 3
                    path.move(to: CGPoint(x: actualRect.minX + thirdWidth, y: actualRect.minY))
                    path.addLine(to: CGPoint(x: actualRect.minX + thirdWidth, y: actualRect.maxY))
                    path.move(to: CGPoint(x: actualRect.minX + thirdWidth * 2, y: actualRect.minY))
                    path.addLine(to: CGPoint(x: actualRect.minX + thirdWidth * 2, y: actualRect.maxY))

                    // 가로 라인 2개
                    let thirdHeight = actualRect.height / 3
                    path.move(to: CGPoint(x: actualRect.minX, y: actualRect.minY + thirdHeight))
                    path.addLine(to: CGPoint(x: actualRect.maxX, y: actualRect.minY + thirdHeight))
                    path.move(to: CGPoint(x: actualRect.minX, y: actualRect.minY + thirdHeight * 2))
                    path.addLine(to: CGPoint(x: actualRect.maxX, y: actualRect.minY + thirdHeight * 2))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                .allowsHitTesting(false)

                // 이동 가능한 중앙 영역
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: actualRect.width, height: actualRect.height)
                    .position(x: actualRect.midX, y: actualRect.midY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragType == .none {
                                    startCropRect = cropRect
                                    dragType = .move
                                }

                                let translation = value.translation
                                let normalizedTranslation = CGPoint(
                                    x: translation.width / geometry.size.width,
                                    y: translation.height / geometry.size.height
                                )

                                var newRect = startCropRect
                                newRect.origin.x += normalizedTranslation.x
                                newRect.origin.y += normalizedTranslation.y

                                // 경계 체크
                                newRect.origin.x = max(0, min(newRect.origin.x, 1.0 - newRect.width))
                                newRect.origin.y = max(0, min(newRect.origin.y, 1.0 - newRect.height))

                                onCropRectChanged(newRect)
                            }
                            .onEnded { _ in
                                dragType = .none
                            }
                    )

                // 코너 핸들
                cornerHandle(at: actualRect.origin, type: .topLeft, in: geometry)
                cornerHandle(at: CGPoint(x: actualRect.maxX, y: actualRect.minY), type: .topRight, in: geometry)
                cornerHandle(at: CGPoint(x: actualRect.minX, y: actualRect.maxY), type: .bottomLeft, in: geometry)
                cornerHandle(at: CGPoint(x: actualRect.maxX, y: actualRect.maxY), type: .bottomRight, in: geometry)

                // 엣지 핸들
                edgeHandle(at: CGPoint(x: actualRect.midX, y: actualRect.minY), type: .top, in: geometry)
                edgeHandle(at: CGPoint(x: actualRect.midX, y: actualRect.maxY), type: .bottom, in: geometry)
                edgeHandle(at: CGPoint(x: actualRect.minX, y: actualRect.midY), type: .left, in: geometry)
                edgeHandle(at: CGPoint(x: actualRect.maxX, y: actualRect.midY), type: .right, in: geometry)
            }
        }
    }

    // 코너 핸들
    @ViewBuilder
    private func cornerHandle(at position: CGPoint, type: DragType, in geometry: GeometryProxy) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
            )
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragType == .none {
                            startCropRect = cropRect
                            dragType = type
                        }
                        handleCornerDrag(value, type: type, geometry: geometry)
                    }
                    .onEnded { _ in
                        dragType = .none
                    }
            )
    }

    // 엣지 핸들
    @ViewBuilder
    private func edgeHandle(at position: CGPoint, type: DragType, in geometry: GeometryProxy) -> some View {
        let isHorizontal = type == .left || type == .right

        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(
                width: isHorizontal ? 8 : 40,
                height: isHorizontal ? 40 : 8
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragType == .none {
                            startCropRect = cropRect
                            dragType = type
                        }
                        handleEdgeDrag(value, type: type, geometry: geometry)
                    }
                    .onEnded { _ in
                        dragType = .none
                    }
            )
    }

    // 코너 드래그 처리
    private func handleCornerDrag(_ value: DragGesture.Value, type: DragType, geometry: GeometryProxy) {
        let translation = value.translation
        let normalizedTranslation = CGPoint(
            x: translation.width / geometry.size.width,
            y: translation.height / geometry.size.height
        )

        var newRect = startCropRect
        let minSize: CGFloat = 0.1  // 최소 크기 10%

        switch type {
        case .topLeft:
            newRect.origin.x += normalizedTranslation.x
            newRect.origin.y += normalizedTranslation.y
            newRect.size.width -= normalizedTranslation.x
            newRect.size.height -= normalizedTranslation.y

        case .topRight:
            newRect.origin.y += normalizedTranslation.y
            newRect.size.width += normalizedTranslation.x
            newRect.size.height -= normalizedTranslation.y

        case .bottomLeft:
            newRect.origin.x += normalizedTranslation.x
            newRect.size.width -= normalizedTranslation.x
            newRect.size.height += normalizedTranslation.y

        case .bottomRight:
            newRect.size.width += normalizedTranslation.x
            newRect.size.height += normalizedTranslation.y

        default:
            break
        }

        // 최소 크기 체크
        if newRect.width < minSize || newRect.height < minSize {
            return
        }

        // 경계 체크
        newRect.origin.x = max(0, newRect.origin.x)
        newRect.origin.y = max(0, newRect.origin.y)
        newRect.size.width = min(newRect.size.width, 1.0 - newRect.origin.x)
        newRect.size.height = min(newRect.size.height, 1.0 - newRect.origin.y)

        onCropRectChanged(newRect)
    }

    // 엣지 드래그 처리
    private func handleEdgeDrag(_ value: DragGesture.Value, type: DragType, geometry: GeometryProxy) {
        let translation = value.translation
        let normalizedTranslation = CGPoint(
            x: translation.width / geometry.size.width,
            y: translation.height / geometry.size.height
        )

        var newRect = startCropRect
        let minSize: CGFloat = 0.1

        switch type {
        case .top:
            newRect.origin.y += normalizedTranslation.y
            newRect.size.height -= normalizedTranslation.y

        case .bottom:
            newRect.size.height += normalizedTranslation.y

        case .left:
            newRect.origin.x += normalizedTranslation.x
            newRect.size.width -= normalizedTranslation.x

        case .right:
            newRect.size.width += normalizedTranslation.x

        default:
            break
        }

        // 최소 크기 체크
        if newRect.width < minSize || newRect.height < minSize {
            return
        }

        // 경계 체크
        newRect.origin.x = max(0, newRect.origin.x)
        newRect.origin.y = max(0, newRect.origin.y)
        newRect.size.width = min(newRect.size.width, 1.0 - newRect.origin.x)
        newRect.size.height = min(newRect.size.height, 1.0 - newRect.origin.y)

        onCropRectChanged(newRect)
    }
}
