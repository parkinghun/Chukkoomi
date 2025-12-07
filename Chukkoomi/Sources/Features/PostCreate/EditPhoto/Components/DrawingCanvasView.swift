//
//  DrawingCanvasView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI
import PencilKit

/// PencilKit 캔버스 뷰 래퍼
/// - PKCanvasView를 SwiftUI에서 사용
/// - Undo/Redo 지원
/// - 손가락 + Apple Pencil 입력 모두 지원
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let tool: PKTool
    let undoTrigger: UUID?
    let redoTrigger: UUID?
    let onDrawingChanged: (PKDrawing) -> Void
    let onUndoStatusChanged: (Bool, Bool) -> Void  // (canUndo, canRedo)

    // MARK: - Constants

    /// Undo 스택 최대 크기
    private static let maxUndoLevels = 20

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawing = drawing
        canvasView.tool = tool
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput  // 손가락 + Apple Pencil 모두 지원

        // UndoManager 설정
        canvasView.undoManager?.levelsOfUndo = Self.maxUndoLevels

        // Coordinator에 canvasView 참조 저장
        context.coordinator.canvasView = canvasView

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Drawing 업데이트 (외부에서 변경된 경우)
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }

        // Tool 업데이트
        uiView.tool = tool

        // Undo trigger 확인
        if let undoTrigger = undoTrigger, undoTrigger != context.coordinator.lastUndoTrigger {
            context.coordinator.lastUndoTrigger = undoTrigger
            context.coordinator.performUndo()
        }

        // Redo trigger 확인
        if let redoTrigger = redoTrigger, redoTrigger != context.coordinator.lastRedoTrigger {
            context.coordinator.lastRedoTrigger = redoTrigger
            context.coordinator.performRedo()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            drawingBinding: $drawing,
            onDrawingChanged: onDrawingChanged,
            onUndoStatusChanged: onUndoStatusChanged
        )
    }

    // MARK: - Coordinator

    /// PKCanvasViewDelegate를 처리하는 Coordinator
    /// - 순환 참조 방지를 위해 클로저 캡처 사용
    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        let onDrawingChanged: (PKDrawing) -> Void
        let onUndoStatusChanged: (Bool, Bool) -> Void

        weak var canvasView: PKCanvasView?
        var lastUndoTrigger: UUID?
        var lastRedoTrigger: UUID?

        init(
            drawingBinding: Binding<PKDrawing>,
            onDrawingChanged: @escaping (PKDrawing) -> Void,
            onUndoStatusChanged: @escaping (Bool, Bool) -> Void
        ) {
            self._drawing = drawingBinding
            self.onDrawingChanged = onDrawingChanged
            self.onUndoStatusChanged = onUndoStatusChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
            onDrawingChanged(canvasView.drawing)

            // Undo/Redo 상태 업데이트
            let canUndo = canvasView.undoManager?.canUndo ?? false
            let canRedo = canvasView.undoManager?.canRedo ?? false
            onUndoStatusChanged(canUndo, canRedo)
        }

        func performUndo() {
            canvasView?.undoManager?.undo()
        }

        func performRedo() {
            canvasView?.undoManager?.redo()
        }
    }
}
