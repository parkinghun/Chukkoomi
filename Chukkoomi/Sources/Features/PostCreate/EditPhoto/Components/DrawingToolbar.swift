//
//  DrawingToolbar.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

struct DrawingToolbar: View {
    let selectedTool: EditPhotoFeature.DrawingTool
    let currentColor: Color
    let canUndo: Bool
    let canRedo: Bool
    let onToolSelected: (EditPhotoFeature.DrawingTool) -> Void
    let onColorTap: () -> Void
    let onBrushTap: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Drawing Tools
            ForEach(EditPhotoFeature.DrawingTool.allCases) { tool in
                ToolButton(
                    icon: tool.icon,
                    isSelected: selectedTool == tool,
                    action: {
                        onToolSelected(tool)
                    }
                )
            }

            Divider()
                .frame(height: 24)
                .background(Color.gray.opacity(0.3))

            // Color Palette Button
            Button(action: onColorTap) {
                Circle()
                    .fill(currentColor)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
            }

            // Brush Thickness Button
            ToolButton(
                icon: "line.3.horizontal.decrease",
                isSelected: false,
                action: onBrushTap
            )

            Divider()
                .frame(height: 24)
                .background(Color.gray.opacity(0.3))

            // Undo Button
            ToolButton(
                icon: "arrow.uturn.backward",
                isSelected: false,
                isEnabled: canUndo,
                action: onUndo
            )

            // Redo Button
            ToolButton(
                icon: "arrow.uturn.forward",
                isSelected: false,
                isEnabled: canRedo,
                action: onRedo
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Tool Button
struct ToolButton: View {
    let icon: String
    let isSelected: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .white : (isEnabled ? .primary : .gray.opacity(0.3)))
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .shadow(
                    color: isSelected ? Color.blue.opacity(0.3) : Color.clear,
                    radius: 3,
                    x: 0,
                    y: 1
                )
        }
        .disabled(!isEnabled)
    }
}
