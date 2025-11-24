//
//  EditPhotoFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI
import UIKit
import PencilKit

@Reducer
struct EditPhotoFeature {

    // MARK: - EditMode
    enum EditMode: String, CaseIterable, Identifiable {
        case text = "텍스트"
        case draw = "그리기"
        case filter = "필터"
        case sticker = "스티커"
        case crop = "자르기"

        var id: String { rawValue }

        var icon: Image {
            switch self {
            case .text: return AppIcon.text
            case .draw: return AppIcon.draw
            case .filter: return AppIcon.filter
            case .sticker: return AppIcon.sticker
            case .crop: return AppIcon.crop
            }
        }
    }

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

    // MARK: - CropAspectRatio
    enum CropAspectRatio: String, CaseIterable, Identifiable {
        case free = "자유"
        case square = "1:1"
        case ratio3_4 = "3:4"
        case ratio4_3 = "4:3"
        case ratio9_16 = "9:16"
        case ratio16_9 = "16:9"

        var id: String { rawValue }

        var ratio: CGFloat? {
            switch self {
            case .free: return nil
            case .square: return 1.0
            case .ratio3_4: return 3.0 / 4.0
            case .ratio4_3: return 4.0 / 3.0
            case .ratio9_16: return 9.0 / 16.0
            case .ratio16_9: return 16.0 / 9.0
            }
        }
    }

    // MARK: - TextOverlay
    struct TextOverlay: Equatable, Identifiable {
        let id: UUID
        var text: String
        var position: CGPoint  // Normalized (0.0~1.0)
        var color: Color
        var fontSize: CGFloat

        init(
            id: UUID = UUID(),
            text: String = "",
            position: CGPoint = CGPoint(x: 0.5, y: 0.5),  // 중앙
            color: Color = .white,
            fontSize: CGFloat = 32
        ) {
            self.id = id
            self.text = text
            self.position = position
            self.color = color
            self.fontSize = fontSize
        }
    }

    // MARK: - StickerOverlay
    struct StickerOverlay: Equatable, Identifiable {
        let id: UUID
        var imageName: String
        var position: CGPoint  // Normalized (0.0~1.0)
        var scale: CGFloat
        var rotation: Angle

        init(
            id: UUID = UUID(),
            imageName: String,
            position: CGPoint = CGPoint(x: 0.5, y: 0.5),  // 중앙
            scale: CGFloat = 1.0,
            rotation: Angle = .zero
        ) {
            self.id = id
            self.imageName = imageName
            self.position = position
            self.scale = scale
            self.rotation = rotation
        }
    }

    // MARK: - EditSnapshot (Undo/Redo용)
    struct EditSnapshot: Equatable {
        let displayImage: UIImage
        let selectedFilter: ImageFilter
        let textOverlays: [TextOverlay]
        let stickers: [StickerOverlay]
        let cropRect: CGRect?
        let selectedAspectRatio: CropAspectRatio
        let pkDrawing: PKDrawing

        static func == (lhs: EditSnapshot, rhs: EditSnapshot) -> Bool {
            // UIImage 비교는 pngData로 변환하여 비교 (간단하게 참조만 비교)
            return lhs.displayImage === rhs.displayImage &&
                   lhs.selectedFilter == rhs.selectedFilter &&
                   lhs.textOverlays == rhs.textOverlays &&
                   lhs.stickers == rhs.stickers &&
                   lhs.cropRect == rhs.cropRect &&
                   lhs.selectedAspectRatio == rhs.selectedAspectRatio &&
                   lhs.pkDrawing.dataRepresentation() == rhs.pkDrawing.dataRepresentation()
        }
    }

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var originalImage: UIImage
        var displayImage: UIImage  // 현재 화면에 표시되는 이미지
        var selectedEditMode: EditMode = .filter  // 기본값: 필터

        // Filter
        var selectedFilter: ImageFilter = .original
        var previewFilter: ImageFilter?  // 드래그 중인 필터 (라이브 프리뷰)
        var filterThumbnails: [ImageFilter: UIImage] = [:]

        // Crop
        var cropRect: CGRect?  // 자를 영역 (normalized 0.0~1.0)
        var selectedAspectRatio: CropAspectRatio = .free
        var isCropping: Bool = false

        // Text
        var textOverlays: [TextOverlay] = []
        var editingTextId: UUID?  // 현재 편집 중인 텍스트 ID
        var isTextEditMode: Bool = false  // 텍스트 편집 모드 활성화 여부
        var currentTextColor: Color = .white
        var currentTextFontSize: CGFloat = 32

        // Drawing
        var pkDrawing: PKDrawing = PKDrawing()  // PencilKit drawing
        var canvasSize: CGSize = .zero  // DrawingCanvas의 실제 크기 (포인트)
        var selectedDrawingTool: DrawingTool = .pen
        var drawingColor: Color = .black
        var drawingWidth: CGFloat = 5.0
        var isDrawingToolCustomizationPresented: Bool = false
        var canUndoDrawing: Bool = false
        var canRedoDrawing: Bool = false
        var undoDrawingTrigger: UUID?
        var redoDrawingTrigger: UUID?

        // Sticker
        var stickers: [StickerOverlay] = []
        var selectedStickerId: UUID?
        var availableStickers: [String] = (1...13).map { "sticker_\($0)" }

        // Undo/Redo
        var historyStack: [EditSnapshot] = []
        var redoStack: [EditSnapshot] = []
        var maxHistorySize: Int = 20  // 최대 히스토리 개수

        // Common
        var isProcessing: Bool = false
        var isDragging: Bool = false

        init(originalImage: UIImage) {
            self.originalImage = originalImage
            self.displayImage = originalImage
        }

        // Undo/Redo 가능 여부 계산
        var canUndo: Bool {
            !historyStack.isEmpty
        }

        var canRedo: Bool {
            !redoStack.isEmpty
        }

        // 현재 상태의 스냅샷 생성
        func createSnapshot() -> EditSnapshot {
            EditSnapshot(
                displayImage: displayImage,
                selectedFilter: selectedFilter,
                textOverlays: textOverlays,
                stickers: stickers,
                cropRect: cropRect,
                selectedAspectRatio: selectedAspectRatio,
                pkDrawing: pkDrawing
            )
        }

        // 스냅샷으로부터 상태 복원
        mutating func restoreFromSnapshot(_ snapshot: EditSnapshot) {
            displayImage = snapshot.displayImage
            selectedFilter = snapshot.selectedFilter
            textOverlays = snapshot.textOverlays
            stickers = snapshot.stickers
            cropRect = snapshot.cropRect
            selectedAspectRatio = snapshot.selectedAspectRatio
            pkDrawing = snapshot.pkDrawing
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case editModeChanged(EditMode)

        // Filter Actions
        case generateFilterThumbnails
        case filterThumbnailGenerated(ImageFilter, UIImage)
        case filterDragStarted(ImageFilter)
        case filterDragEntered  // Preview Canvas 위로 드래그
        case filterDragExited   // Preview Canvas에서 벗어남
        case filterDropped(ImageFilter)
        case filterDragCancelled
        case applyFilter(ImageFilter)
        case filterApplied(UIImage)

        // Crop Actions
        case cropRectChanged(CGRect)
        case aspectRatioChanged(CropAspectRatio)
        case applyCrop
        case cropApplied(UIImage)
        case resetCrop

        // Text Actions
        case enterTextEditMode(CGPoint)  // 텍스트 편집 모드 진입 (새 텍스트, 터치 위치)
        case editExistingText(UUID)  // 기존 텍스트 편집 (수정)
        case exitTextEditMode  // 텍스트 편집 모드 종료
        case updateEditingText(UUID, String)  // 편집 중 텍스트 업데이트
        case textColorChanged(Color)
        case textFontSizeChanged(CGFloat)
        case textOverlayPositionChanged(UUID, CGPoint)
        case deleteSelectedText
        case tapImageEmptySpace(CGPoint)  // 이미지 빈 공간 탭 (터치 위치)

        // Drawing Actions
        case setCanvasSize(CGSize)
        case drawingToolSelected(DrawingTool)
        case drawingColorChanged(Color)
        case drawingWidthChanged(CGFloat)
        case toggleDrawingToolCustomization
        case drawingChanged(PKDrawing)
        case drawingUndoStatusChanged(canUndo: Bool, canRedo: Bool)
        case drawingUndo
        case drawingRedo
        case applyDrawingToImage
        case drawingApplied(UIImage)

        // Sticker Actions
        case addSticker(String)  // 스티커 추가 (imageName)
        case selectSticker(UUID?)  // 스티커 선택/해제
        case updateStickerPosition(UUID, CGPoint)  // 위치 업데이트
        case updateStickerScale(UUID, CGFloat)  // 크기 업데이트
        case updateStickerRotation(UUID, Angle)  // 회전 업데이트
        case updateStickerTransform(UUID, CGPoint, CGFloat, Angle)  // 위치+크기+회전 동시 업데이트
        case deleteSticker(UUID)  // 스티커 삭제

        // Undo/Redo Actions
        case saveSnapshot
        case undo
        case redo

        // Common
        case completeButtonTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didCompleteEditing(Data)
        }
    }

    // MARK: - Dependencies
    @Dependency(\.dismiss) var dismiss
    private let filterCache = FilterCacheManager()

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.generateFilterThumbnails)

            case let .editModeChanged(mode):
                // 그리기 모드를 벗어날 때 drawing을 displayImage에 적용
                let wasDrawingMode = state.selectedEditMode == .draw
                let isLeavingDrawingMode = wasDrawingMode && mode != .draw
                let hasDrawing = !state.pkDrawing.strokes.isEmpty

                // 다른 모드로 전환 시 텍스트 편집 모드 종료
                if mode != .text && state.isTextEditMode {
                    // 빈 텍스트면 삭제
                    if let editingId = state.editingTextId,
                       let overlay = state.textOverlays.first(where: { $0.id == editingId }),
                       overlay.text.isEmpty {
                        state.textOverlays.removeAll(where: { $0.id == editingId })
                    }
                    state.editingTextId = nil
                    state.isTextEditMode = false
                }

                state.selectedEditMode = mode

                // 필터 모드로 전환할 때 썸네일이 없으면 생성
                if mode == .filter && state.filterThumbnails.isEmpty {
                    return .send(.generateFilterThumbnails)
                }

                // Crop 모드로 전환 시 초기 cropRect 설정 (전체 이미지)
                if mode == .crop && state.cropRect == nil {
                    state.cropRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
                }

                // 그리기 모드를 벗어날 때 drawing 적용
                if isLeavingDrawingMode && hasDrawing {
                    return .send(.applyDrawingToImage)
                }

                return .none

            case .generateFilterThumbnails:
                state.isProcessing = true

                return .run { [originalImage = state.originalImage] send in
                    // 썸네일용 작은 이미지 생성 (성능 최적화)
                    let thumbnailSize = CGSize(width: 100, height: 100)
                    let thumbnailImage = await ImageEditHelper.resizeImage(originalImage, to: thumbnailSize)

                    // 각 필터별 썸네일 생성
                    for filter in ImageFilter.allCases {
                        if let filtered = filter.apply(to: thumbnailImage) {
                            await send(.filterThumbnailGenerated(filter, filtered))
                        }
                    }
                }

            case let .filterThumbnailGenerated(filter, thumbnail):
                state.filterThumbnails[filter] = thumbnail
                // 모든 썸네일이 생성되면 processing 완료
                if state.filterThumbnails.count == ImageFilter.allCases.count {
                    state.isProcessing = false
                }
                return .none

            case let .filterDragStarted(filter):
                state.isDragging = true
                state.previewFilter = filter
                return .none

            case .filterDragEntered:
                // 드래그가 Preview Canvas 위로 진입
                // 현재 previewFilter로 이미지 즉시 업데이트
                if let previewFilter = state.previewFilter {
                    return .send(.applyFilter(previewFilter))
                }
                return .none

            case .filterDragExited:
                // Preview Canvas에서 벗어남 - 원래 선택된 필터로 복원
                state.previewFilter = nil
                return .send(.applyFilter(state.selectedFilter))

            case let .filterDropped(filter):
                state.isDragging = false
                state.previewFilter = nil
                state.selectedFilter = filter
                // 드롭된 필터를 최종 적용
                return .send(.applyFilter(filter))

            case .filterDragCancelled:
                state.isDragging = false
                state.previewFilter = nil
                // 원래 필터로 복원
                return .send(.applyFilter(state.selectedFilter))

            case let .applyFilter(filter):
                state.isProcessing = true

                return .merge(
                    .send(.saveSnapshot),
                    .run { [originalImage = state.originalImage] send in
                        // 전체 해상도 이미지에 필터 적용
                        if let filtered = filter.apply(to: originalImage) {
                            await send(.filterApplied(filtered))
                        } else {
                            await send(.filterApplied(originalImage))
                        }
                    }
                )

            case let .filterApplied(image):
                state.displayImage = image
                state.isProcessing = false
                return .none

            // MARK: - Crop Actions
            case let .cropRectChanged(rect):
                state.cropRect = rect
                return .none

            case let .aspectRatioChanged(ratio):
                state.selectedAspectRatio = ratio
                // 전체 이미지 크기에서 선택한 비율로 cropRect 계산
                if let aspectRatio = ratio.ratio {
                    state.cropRect = ImageEditHelper.calculateCropRectForAspectRatio(aspectRatio)
                } else {
                    // free 비율인 경우 전체 이미지로
                    state.cropRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
                }
                return .none

            case .applyCrop:
                guard let cropRect = state.cropRect else { return .none }
                state.isProcessing = true

                return .merge(
                    .send(.saveSnapshot),
                    .run { [displayImage = state.displayImage] send in
                        // Crop 적용
                        if let croppedImage = await ImageEditHelper.cropImage(displayImage, to: cropRect) {
                            await send(.cropApplied(croppedImage))
                        }
                    }
                )

            case let .cropApplied(image):
                state.displayImage = image
                state.originalImage = image  // 자른 이미지를 새로운 원본으로
                state.cropRect = nil
                state.isCropping = false
                state.isProcessing = false
                return .none

            case .resetCrop:
                // 전체 이미지로 리셋
                state.cropRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
                state.selectedAspectRatio = .free
                return .none

            // MARK: - Text Actions
            case let .tapImageEmptySpace(position):
                // 스티커 모드일 때는 스티커 선택 해제
                if state.selectedEditMode == .sticker {
                    state.selectedStickerId = nil
                    return .none
                }

                // 텍스트 모드가 아니면 무시
                guard state.selectedEditMode == .text else { return .none }
                // 이미 편집 모드면 무시
                guard !state.isTextEditMode else { return .none }

                return .send(.enterTextEditMode(position))

            case let .enterTextEditMode(position):
                // 히스토리에 저장
                let snapshot = state.createSnapshot()
                state.historyStack.append(snapshot)
                if state.historyStack.count > state.maxHistorySize {
                    state.historyStack.removeFirst()
                }
                state.redoStack.removeAll()

                // 텍스트 편집 모드 활성화
                state.isTextEditMode = true

                // 터치한 위치에 새 텍스트 생성
                let newOverlay = TextOverlay(
                    text: "",
                    position: position,  // 터치한 위치 사용
                    color: state.currentTextColor,
                    fontSize: state.currentTextFontSize
                )
                state.textOverlays.append(newOverlay)
                state.editingTextId = newOverlay.id
                return .none

            case let .editExistingText(id):
                // 텍스트 모드가 아니면 무시
                guard state.selectedEditMode == .text else { return .none }
                // 이미 편집 모드면 무시
                guard !state.isTextEditMode else { return .none }

                // 히스토리에 저장
                let snapshot = state.createSnapshot()
                state.historyStack.append(snapshot)
                if state.historyStack.count > state.maxHistorySize {
                    state.historyStack.removeFirst()
                }
                state.redoStack.removeAll()

                // 텍스트 편집 모드 활성화
                state.isTextEditMode = true
                state.editingTextId = id

                if let overlay = state.textOverlays.first(where: { $0.id == id }) {
                    state.currentTextColor = overlay.color
                    state.currentTextFontSize = overlay.fontSize
                }
                return .none

            case let .updateEditingText(id, text):
                // 편집 중 텍스트 업데이트
                if let index = state.textOverlays.firstIndex(where: { $0.id == id }) {
                    state.textOverlays[index].text = text
                }
                return .none

            case .exitTextEditMode:
                // 편집 완료
                // 빈 텍스트면 삭제
                if let editingId = state.editingTextId,
                   let overlay = state.textOverlays.first(where: { $0.id == editingId }),
                   overlay.text.isEmpty {
                    state.textOverlays.removeAll(where: { $0.id == editingId })
                }
                state.editingTextId = nil
                state.isTextEditMode = false
                return .none

            case let .textColorChanged(color):
                state.currentTextColor = color
                // 편집 중인 텍스트가 있으면 색상 업데이트
                if let editingId = state.editingTextId,
                   let index = state.textOverlays.firstIndex(where: { $0.id == editingId }) {
                    state.textOverlays[index].color = color
                }
                return .none

            case let .textFontSizeChanged(size):
                state.currentTextFontSize = size
                // 편집 중인 텍스트가 있으면 크기 업데이트
                if let editingId = state.editingTextId,
                   let index = state.textOverlays.firstIndex(where: { $0.id == editingId }) {
                    state.textOverlays[index].fontSize = size
                }
                return .none

            case let .textOverlayPositionChanged(id, position):
                if let index = state.textOverlays.firstIndex(where: { $0.id == id }) {
                    state.textOverlays[index].position = position
                }
                return .none

            case .deleteSelectedText:
                guard let editingId = state.editingTextId else { return .none }

                // 변경 전 현재 상태를 히스토리에 저장
                let snapshot = state.createSnapshot()
                state.historyStack.append(snapshot)
                if state.historyStack.count > state.maxHistorySize {
                    state.historyStack.removeFirst()
                }
                state.redoStack.removeAll()

                // 텍스트 삭제
                state.textOverlays.removeAll(where: { $0.id == editingId })
                state.editingTextId = nil
                return .none

            // MARK: - Drawing Actions
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
                state.isProcessing = true

                return .run { [
                    displayImage = state.displayImage,
                    drawing = state.pkDrawing,
                    canvasSize = state.canvasSize
                ] send in
                    // Drawing을 이미지에 합성
                    let composited = await ImageEditHelper.compositeImageWithDrawing(
                        baseImage: displayImage,
                        drawing: drawing,
                        canvasSize: canvasSize
                    )
                    await send(.drawingApplied(composited))
                }

            case let .drawingApplied(image):
                state.displayImage = image
                state.pkDrawing = PKDrawing()  // Drawing 초기화
                state.isProcessing = false
                return .none

            // MARK: - Sticker Actions
            case let .addSticker(imageName):
                // 새 스티커 추가 (중앙에 배치)
                let newSticker = StickerOverlay(imageName: imageName)
                state.stickers.append(newSticker)
                // 자동 선택하지 않음 - 사용자가 직접 탭해야 선택됨
                // state.selectedStickerId = newSticker.id
                return .none

            case let .selectSticker(stickerId):
                state.selectedStickerId = stickerId
                return .none

            case let .updateStickerPosition(id, position):
                if let index = state.stickers.firstIndex(where: { $0.id == id }) {
                    state.stickers[index].position = position
                }
                return .none

            case let .updateStickerScale(id, scale):
                if let index = state.stickers.firstIndex(where: { $0.id == id }) {
                    state.stickers[index].scale = scale
                }
                return .none

            case let .updateStickerRotation(id, rotation):
                if let index = state.stickers.firstIndex(where: { $0.id == id }) {
                    state.stickers[index].rotation = rotation
                }
                return .none

            case let .updateStickerTransform(id, position, scale, rotation):
                if let index = state.stickers.firstIndex(where: { $0.id == id }) {
                    state.stickers[index].position = position
                    state.stickers[index].scale = scale
                    state.stickers[index].rotation = rotation
                }
                return .none

            case let .deleteSticker(id):
                state.stickers.removeAll(where: { $0.id == id })
                if state.selectedStickerId == id {
                    state.selectedStickerId = nil
                }
                return .none

            // MARK: - Undo/Redo Actions
            case .saveSnapshot:
                // 현재 상태를 히스토리에 저장
                let snapshot = state.createSnapshot()
                state.historyStack.append(snapshot)

                // 최대 히스토리 크기 제한
                if state.historyStack.count > state.maxHistorySize {
                    state.historyStack.removeFirst()
                }

                // 새로운 작업 시 redo 스택 클리어
                state.redoStack.removeAll()
                return .none

            case .undo:
                guard !state.historyStack.isEmpty else { return .none }

                // 현재 상태를 redo 스택에 저장
                let currentSnapshot = state.createSnapshot()
                state.redoStack.append(currentSnapshot)

                // 히스토리에서 이전 상태 복원
                let previousSnapshot = state.historyStack.removeLast()
                state.restoreFromSnapshot(previousSnapshot)

                // 텍스트 편집 모드 종료
                state.editingTextId = nil
                state.isTextEditMode = false

                return .none

            case .redo:
                guard !state.redoStack.isEmpty else { return .none }

                // 현재 상태를 히스토리에 저장
                let currentSnapshot = state.createSnapshot()
                state.historyStack.append(currentSnapshot)

                // Redo 스택에서 다음 상태 복원
                let nextSnapshot = state.redoStack.removeLast()
                state.restoreFromSnapshot(nextSnapshot)

                // 텍스트 편집 모드 종료
                state.editingTextId = nil
                state.isTextEditMode = false

                return .none

            case .completeButtonTapped:
                // 텍스트 편집 모드면 먼저 종료
                if state.isTextEditMode {
                    // 빈 텍스트면 삭제
                    if let editingId = state.editingTextId,
                       let overlay = state.textOverlays.first(where: { $0.id == editingId }),
                       overlay.text.isEmpty {
                        state.textOverlays.removeAll(where: { $0.id == editingId })
                    }
                    state.editingTextId = nil
                    state.isTextEditMode = false
                }

                state.isProcessing = true

                return .run { [
                    displayImage = state.displayImage,
                    cropRect = state.cropRect,
                    textOverlays = state.textOverlays,
                    stickers = state.stickers,
                    drawing = state.pkDrawing,
                    canvasSize = state.canvasSize
                ] send in
                    // 1. 자르기가 설정되어 있으면 먼저 적용
                    var baseImage = displayImage
                    if let cropRect = cropRect {
                        if let croppedImage = await ImageEditHelper.cropImage(displayImage, to: cropRect) {
                            baseImage = croppedImage
                        }
                    }

                    // 2. 텍스트 오버레이, 스티커, 그림을 최종 이미지에 합성
                    let finalImage = await ImageEditHelper.compositeImageWithOverlays(
                        baseImage: baseImage,
                        textOverlays: textOverlays,
                        stickers: stickers,
                        drawing: drawing,
                        canvasSize: canvasSize
                    )

                    guard let imageData = finalImage.jpegData(compressionQuality: 0.8) else {
                        return
                    }

                    // delegate로 전달 (dismiss는 부모에서 처리)
                    await send(.delegate(.didCompleteEditing(imageData)))
                }

            case .delegate:
                return .none
            }
        }
    }

}
