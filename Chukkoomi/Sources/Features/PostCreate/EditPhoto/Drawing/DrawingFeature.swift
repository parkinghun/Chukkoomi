//
//  DrawingFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.
//

import ComposableArchitecture
import Foundation
import SwiftUI
import PencilKit

/// 그리기 기능을 담당하는 Feature
@Reducer
struct DrawingFeature {

    // MARK: - DrawingTool
    enum DrawingTool: String, CaseIterable, Identifiable {
        case pen = "펜"
        case pencil = "연필"
        case marker = "마커"
        case eraser = "지우개"

        var id: String { rawValue }

        var pkTool: PKInkingTool.InkType {
            switch self {
            case .pen: return .pen
            case .pencil: return .pencil
            case .marker: return .marker
            case .eraser: return .pen // eraser는 별도 처리
            }
        }

        var icon: String {
            switch self {
            case .pen: return "pencil.tip"
            case .pencil: return "pencil"
            case .marker: return "highlighter"
            case .eraser: return "eraser.fill"
            }
        }
    }

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        /// PencilKit drawing
        var pkDrawing: PKDrawing = PKDrawing()

        /// DrawingCanvas의 실제 크기 (포인트)
        var canvasSize: CGSize = .zero

        /// 선택된 그리기 도구
        var selectedDrawingTool: DrawingTool = .pen

        /// 그리기 색상
        var drawingColor: Color = .black

        /// 그리기 선 두께
        var drawingWidth: CGFloat = 5.0

        /// 도구 커스터마이징 시트 표시 여부
        var isDrawingToolCustomizationPresented: Bool = false

        /// Undo 가능 여부
        var canUndoDrawing: Bool = false

        /// Redo 가능 여부
        var canRedoDrawing: Bool = false

        /// Undo 트리거 (DrawingCanvasView가 감지)
        var undoDrawingTrigger: UUID?

        /// Redo 트리거 (DrawingCanvasView가 감지)
        var redoDrawingTrigger: UUID?

        init() {}

        static func == (lhs: State, rhs: State) -> Bool {
            // PKDrawing은 dataRepresentation으로 비교
            return lhs.pkDrawing.dataRepresentation() == rhs.pkDrawing.dataRepresentation() &&
                   lhs.canvasSize == rhs.canvasSize &&
                   lhs.selectedDrawingTool == rhs.selectedDrawingTool &&
                   lhs.drawingColor == rhs.drawingColor &&
                   lhs.drawingWidth == rhs.drawingWidth &&
                   lhs.isDrawingToolCustomizationPresented == rhs.isDrawingToolCustomizationPresented &&
                   lhs.canUndoDrawing == rhs.canUndoDrawing &&
                   lhs.canRedoDrawing == rhs.canRedoDrawing &&
                   lhs.undoDrawingTrigger == rhs.undoDrawingTrigger &&
                   lhs.redoDrawingTrigger == rhs.redoDrawingTrigger
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        /// 캔버스 크기 설정
        case setCanvasSize(CGSize)

        /// 그리기 도구 선택
        case drawingToolSelected(DrawingTool)

        /// 그리기 색상 변경
        case drawingColorChanged(Color)

        /// 그리기 선 두께 변경
        case drawingWidthChanged(CGFloat)

        /// 도구 커스터마이징 시트 토글
        case toggleDrawingToolCustomization

        /// Drawing 변경 (PencilKit에서 호출)
        case drawingChanged(PKDrawing)

        /// Undo/Redo 상태 변경 (PencilKit에서 호출)
        case drawingUndoStatusChanged(canUndo: Bool, canRedo: Bool)

        /// Undo 실행
        case drawingUndo

        /// Redo 실행
        case drawingRedo

        /// Drawing을 이미지에 적용 (그리기 모드 종료 시)
        case applyDrawingToImage

        /// Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            /// Drawing이 이미지에 적용됨
            case drawingApplied(UIImage)
        }

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case let (.setCanvasSize(l), .setCanvasSize(r)):
                return l == r
            case let (.drawingToolSelected(l), .drawingToolSelected(r)):
                return l == r
            case let (.drawingColorChanged(l), .drawingColorChanged(r)):
                return l == r
            case let (.drawingWidthChanged(l), .drawingWidthChanged(r)):
                return l == r
            case (.toggleDrawingToolCustomization, .toggleDrawingToolCustomization),
                 (.drawingUndo, .drawingUndo),
                 (.drawingRedo, .drawingRedo),
                 (.applyDrawingToImage, .applyDrawingToImage):
                return true
            case (.drawingChanged, .drawingChanged):
                return true  // PKDrawing 비교 생략
            case let (.drawingUndoStatusChanged(lc, lr), .drawingUndoStatusChanged(rc, rr)):
                return lc == rc && lr == rr
            case (.delegate, .delegate):
                return true  // UIImage 포함이므로 true
            default:
                return false
            }
        }
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setCanvasSize(size):
                state.canvasSize = size
                return .none

            case let .drawingToolSelected(tool):
                state.selectedDrawingTool = tool
                return .none

            case let .drawingColorChanged(color):
                state.drawingColor = color
                return .none

            case let .drawingWidthChanged(width):
                state.drawingWidth = width
                return .none

            case .toggleDrawingToolCustomization:
                state.isDrawingToolCustomizationPresented.toggle()
                return .none

            case let .drawingChanged(drawing):
                state.pkDrawing = drawing
                return .none

            case let .drawingUndoStatusChanged(canUndo, canRedo):
                state.canUndoDrawing = canUndo
                state.canRedoDrawing = canRedo
                return .none

            case .drawingUndo:
                // Trigger를 변경하여 DrawingCanvasView에서 undo 수행
                state.undoDrawingTrigger = UUID()
                return .none

            case .drawingRedo:
                // Trigger를 변경하여 DrawingCanvasView에서 redo 수행
                state.redoDrawingTrigger = UUID()
                return .none

            case .applyDrawingToImage:
                // Drawing을 이미지에 합성 요청
                // 부모에서 displayImage를 받아서 합성해야 하므로
                // 실제 합성은 EditPhotoFeature에서 처리
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
