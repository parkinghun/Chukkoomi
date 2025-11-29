//
//  DrawingCanvasView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI
import PencilKit

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let tool: PKTool
    let undoTrigger: UUID?
    let redoTrigger: UUID?
    let onDrawingChanged: (PKDrawing) -> Void
    let onUndoStatusChanged: (Bool, Bool) -> Void  // (canUndo, canRedo)

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawing = drawing
        canvasView.tool = tool
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput  // 손가락 + Apple Pencil 모두 지원

        // UndoManager 설정
        canvasView.undoManager?.levelsOfUndo = 20

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
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        weak var canvasView: PKCanvasView?
        var lastUndoTrigger: UUID?
        var lastRedoTrigger: UUID?

        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onDrawingChanged(canvasView.drawing)

            // Undo/Redo 상태 업데이트
            let canUndo = canvasView.undoManager?.canUndo ?? false
            let canRedo = canvasView.undoManager?.canRedo ?? false
            parent.onUndoStatusChanged(canUndo, canRedo)
        }

        func performUndo() {
            canvasView?.undoManager?.undo()
        }

        func performRedo() {
            canvasView?.undoManager?.redo()
        }
    }
}
