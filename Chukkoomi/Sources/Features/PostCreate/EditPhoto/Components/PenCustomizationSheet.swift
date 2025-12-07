//
//  PenCustomizationSheet.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

/// 펜 커스터마이징 시트
/// - 도구 선택 (펜/연필/마커/지우개)
/// - 색상 선택
/// - 굵기 조절
struct PenCustomizationSheet: View {
    let selectedTool: EditPhotoFeature.DrawingTool
    let currentColor: Color
    let currentWidth: CGFloat
    let onToolSelected: (EditPhotoFeature.DrawingTool) -> Void
    let onColorChanged: (Color) -> Void
    let onWidthChanged: (CGFloat) -> Void

    // MARK: - Constants

    /// 손잡이 인디케이터 너비
    private static let handleWidth: CGFloat = 36
    /// 손잡이 인디케이터 높이
    private static let handleHeight: CGFloat = 5
    /// 색상 그리드 열 개수
    private static let colorGridColumns = 6
    /// 색상 그리드 간격
    private static let colorGridSpacing: CGFloat = 12
    /// 브러시 굵기 최소값
    private static let minBrushWidth: CGFloat = 1
    /// 브러시 굵기 최대값
    private static let maxBrushWidth: CGFloat = 20
    /// 브러시 굵기 스텝
    private static let brushWidthStep: CGFloat = 0.5
    /// 시트 높이 (지우개 모드)
    private static let eraserSheetHeight: CGFloat = 200
    /// 시트 높이 (일반 모드)
    private static let normalSheetHeight: CGFloat = 450

    var body: some View {
        VStack(spacing: 24) {
            // Handle Indicator
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: Self.handleWidth, height: Self.handleHeight)
                .padding(.top, 8)

            // Tool Types
            VStack(alignment: .leading, spacing: 12) {
                Text("도구 선택")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    ForEach(EditPhotoFeature.DrawingTool.allCases) { tool in
                        ToolTypeButton(
                            tool: tool,
                            isSelected: selectedTool == tool,
                            action: {
                                onToolSelected(tool)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)

            Divider()

            // Color Palette
            if selectedTool != .eraser {
                VStack(alignment: .leading, spacing: 12) {
                    Text("색상")
                        .font(.headline)
                        .foregroundColor(.primary)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: Self.colorGridSpacing), count: Self.colorGridColumns),
                        spacing: Self.colorGridSpacing
                    ) {
                        ForEach(AppColor.editingPalette, id: \.self) { color in
                            ColorButton(
                                color: color,
                                isSelected: colorsAreEqual(currentColor, color),
                                action: {
                                    onColorChanged(color)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)

                Divider()
            }

            // Brush Thickness
            if selectedTool != .eraser {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("굵기")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        // Preview of current stroke
                        Capsule()
                            .fill(currentColor)
                            .frame(width: 60, height: currentWidth)
                    }

                    Slider(
                        value: Binding(
                            get: { currentWidth },
                            set: { onWidthChanged($0) }
                        ),
                        in: Self.minBrushWidth...Self.maxBrushWidth,
                        step: Self.brushWidthStep
                    )
                    .tint(currentColor)
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .presentationDetents([.height(selectedTool == .eraser ? Self.eraserSheetHeight : Self.normalSheetHeight)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Helper Functions

    /// 두 색상이 거의 같은지 비교 (RGB 값 기준)
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let tolerance: CGFloat = 0.01
        return abs(r1 - r2) < tolerance &&
               abs(g1 - g2) < tolerance &&
               abs(b1 - b2) < tolerance
    }
}

// MARK: - Tool Type Button
struct ToolTypeButton: View {
    let tool: EditPhotoFeature.DrawingTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                    )
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.3) : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )

                Text(tool.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
        }
    }
}

// MARK: - Color Button
struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .strokeBorder(
                            color == Color.white ? Color.gray.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.blue : Color.clear,
                            lineWidth: 3
                        )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
        }
    }
}
