//
//  CropOverlayView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

/// 크롭 오버레이 뷰
/// - 드래그 가능한 크롭 영역 표시
/// - 코너/엣지 핸들로 크기 조절
/// - 3x3 그리드 가이드라인
struct CropOverlayView: View {
    let cropRect: CGRect  // Normalized (0.0~1.0)
    let imageSize: CGSize
    let onCropRectChanged: (CGRect) -> Void

    @State private var startCropRect: CGRect = .zero
    @State private var dragType: DragType = .none

    // MARK: - Constants

    /// 코너 핸들 크기
    private static let cornerHandleSize: CGFloat = 20
    /// 엣지 핸들 두께
    private static let edgeHandleThickness: CGFloat = 8
    /// 엣지 핸들 길이
    private static let edgeHandleLength: CGFloat = 40
    /// 크롭 영역 최소 크기 (정규화 좌표)
    private static let minCropSize: CGFloat = 0.1
    /// 그리드 라인 투명도
    private static let gridLineOpacity: Double = 0.5
    /// 오버레이 투명도
    private static let overlayOpacity: Double = 0.5

    enum DragType {
        case none
        case move
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    // MARK: - Helper Functions

    /// 정규화된 CGRect를 픽셀 CGRect로 변환
    private func denormalize(_ normalized: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: normalized.origin.x * size.width,
            y: normalized.origin.y * size.height,
            width: normalized.width * size.width,
            height: normalized.height * size.height
        )
    }

    /// 픽셀 translation을 정규화된 CGPoint로 변환
    private func normalizeTranslation(_ translation: CGSize, size: CGSize) -> CGPoint {
        CGPoint(
            x: translation.width / size.width,
            y: translation.height / size.height
        )
    }

    /// CGRect를 0.0~1.0 범위로 제한
    private func clampRect(_ rect: CGRect) -> CGRect {
        var clamped = rect

        // 위치 제한
        clamped.origin.x = max(0, clamped.origin.x)
        clamped.origin.y = max(0, clamped.origin.y)

        // 크기 제한
        clamped.size.width = min(clamped.size.width, 1.0 - clamped.origin.x)
        clamped.size.height = min(clamped.size.height, 1.0 - clamped.origin.y)

        return clamped
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let actualRect = denormalize(cropRect, size: geometry.size)

            ZStack {
                // 반투명 오버레이 (크롭 영역 제외)
                Color.black.opacity(Self.overlayOpacity)
                    .mask {
                        ZStack {
                            Rectangle()
                                .fill(Color.white)
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: actualRect.width, height: actualRect.height)
                                .position(x: actualRect.midX, y: actualRect.midY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                    .allowsHitTesting(false)

                // 크롭 영역 테두리
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: actualRect.width, height: actualRect.height)
                    .position(x: actualRect.midX, y: actualRect.midY)
                    .allowsHitTesting(false)

                // 3x3 그리드 가이드라인
                gridLines(in: actualRect)
                    .stroke(Color.white.opacity(Self.gridLineOpacity), lineWidth: 1)
                    .allowsHitTesting(false)

                // 크롭 영역 이동 제스처
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: actualRect.width, height: actualRect.height)
                    .position(x: actualRect.midX, y: actualRect.midY)
                    .gesture(moveGesture(in: geometry))

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

    // MARK: - View Components

    /// 3x3 그리드 라인 Path
    private func gridLines(in rect: CGRect) -> Path {
        Path { path in
            let thirdWidth = rect.width / 3
            let thirdHeight = rect.height / 3

            // 세로 라인 2개
            path.move(to: CGPoint(x: rect.minX + thirdWidth, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.maxY))

            path.move(to: CGPoint(x: rect.minX + thirdWidth * 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + thirdWidth * 2, y: rect.maxY))

            // 가로 라인 2개
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + thirdHeight))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + thirdHeight))

            path.move(to: CGPoint(x: rect.minX, y: rect.minY + thirdHeight * 2))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + thirdHeight * 2))
        }
    }

    /// 크롭 영역 이동 제스처
    private func moveGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragType == .none {
                    startCropRect = cropRect
                    dragType = .move
                }

                let normalizedTranslation = normalizeTranslation(value.translation, size: geometry.size)

                var newRect = startCropRect
                newRect.origin.x += normalizedTranslation.x
                newRect.origin.y += normalizedTranslation.y

                // 이동 시에는 크기는 그대로, 위치만 제한
                newRect.origin.x = max(0, min(newRect.origin.x, 1.0 - newRect.width))
                newRect.origin.y = max(0, min(newRect.origin.y, 1.0 - newRect.height))

                onCropRectChanged(newRect)
            }
            .onEnded { _ in
                dragType = .none
            }
    }

    /// 코너 핸들 뷰
    @ViewBuilder
    private func cornerHandle(at position: CGPoint, type: DragType, in geometry: GeometryProxy) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: Self.cornerHandleSize, height: Self.cornerHandleSize)
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
            )
            .position(position)
            .gesture(resizeGesture(type: type, in: geometry))
    }

    /// 엣지 핸들 뷰
    @ViewBuilder
    private func edgeHandle(at position: CGPoint, type: DragType, in geometry: GeometryProxy) -> some View {
        let isHorizontal = type == .left || type == .right

        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(
                width: isHorizontal ? Self.edgeHandleThickness : Self.edgeHandleLength,
                height: isHorizontal ? Self.edgeHandleLength : Self.edgeHandleThickness
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .position(position)
            .gesture(resizeGesture(type: type, in: geometry))
    }

    // MARK: - Gesture Handlers

    /// 리사이즈 제스처 (코너 & 엣지 공통)
    private func resizeGesture(type: DragType, in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragType == .none {
                    startCropRect = cropRect
                    dragType = type
                }
                handleResize(value, type: type, geometry: geometry)
            }
            .onEnded { _ in
                dragType = .none
            }
    }

    /// 리사이즈 처리 (코너 & 엣지 통합)
    private func handleResize(_ value: DragGesture.Value, type: DragType, geometry: GeometryProxy) {
        let normalizedTranslation = normalizeTranslation(value.translation, size: geometry.size)

        var newRect = startCropRect

        // DragType에 따라 크기 조절
        switch type {
        // 코너 핸들
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

        // 엣지 핸들
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
            return
        }

        // 최소 크기 체크
        if newRect.width < Self.minCropSize || newRect.height < Self.minCropSize {
            return
        }

        // 0.0~1.0 범위로 제한 및 콜백
        onCropRectChanged(clampRect(newRect))
    }
}
