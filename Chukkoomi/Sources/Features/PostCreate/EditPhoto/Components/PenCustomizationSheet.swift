//
//  PenCustomizationSheet.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

struct PenCustomizationSheet: View {
    let selectedTool: EditPhotoFeature.DrawingTool
    let currentColor: Color
    let currentWidth: CGFloat
    let onToolSelected: (EditPhotoFeature.DrawingTool) -> Void
    let onColorChanged: (Color) -> Void
    let onWidthChanged: (CGFloat) -> Void

    // Apple-style color palette
    private let colors: [Color] = [
        Color(red: 0.0, green: 0.0, blue: 0.0),        // Black
        Color(red: 0.5, green: 0.5, blue: 0.5),        // Gray
        Color(red: 1.0, green: 1.0, blue: 1.0),        // White
        Color(red: 1.0, green: 0.23, blue: 0.19),      // Red
        Color(red: 1.0, green: 0.58, blue: 0.0),       // Orange
        Color(red: 1.0, green: 0.8, blue: 0.0),        // Yellow
        Color(red: 0.2, green: 0.78, blue: 0.35),      // Green
        Color(red: 0.0, green: 0.48, blue: 1.0),       // Blue
        Color(red: 0.35, green: 0.34, blue: 0.84),     // Indigo
        Color(red: 0.69, green: 0.32, blue: 0.87),     // Purple
        Color(red: 1.0, green: 0.18, blue: 0.33),      // Pink
        Color(red: 0.55, green: 0.27, blue: 0.07),     // Brown
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Handle Indicator
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // Tool Types
            VStack(alignment: .leading, spacing: 12) {
                Text("도구 선택")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    ForEach([EditPhotoFeature.DrawingTool.pen, .pencil, .marker, .eraser]) { tool in
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

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
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
                        in: 1...20,
                        step: 0.5
                    )
                    .tint(currentColor)
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .presentationDetents([.height(selectedTool == .eraser ? 200 : 450)])
        .presentationDragIndicator(.hidden)
    }

    // Helper function to compare colors
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
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
