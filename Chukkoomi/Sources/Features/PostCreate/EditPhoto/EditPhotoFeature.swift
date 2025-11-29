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
import WebKit

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
            case .text: return AppIcon.subtitle
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

        // Payment (결제 관련)
        var webView: WKWebView?
        var isPurchaseModalPresented: Bool = false
        var pendingPurchaseFilter: PaidFilter?
        var isProcessingPayment: Bool = false
        var paymentError: String?
        var availableFilters: [PaidFilter] = []  // 사용 가능한 유료 필터 목록
        var purchasedFilterPostIds: Set<String> = []  // 구매한 필터의 postId

        // 구매한 ImageFilter 타입 계산
        var purchasedFilterTypes: Set<ImageFilter> {
            Set(availableFilters
                .filter { purchasedFilterPostIds.contains($0.id) }
                .map { $0.imageFilter }
            )
        }

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
    enum Action {
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

        // Payment Actions
        case loadPurchaseHistory
        case purchaseHistoryLoaded([PaidFilter], Set<String>)  // availableFilters, purchasedPostIds
        case webViewCreated(WKWebView)
        case checkPaidFilterPurchase  // 유료 필터 구매 확인
        case showPurchaseModal(PaidFilter)
        case dismissPurchaseModal
        case purchaseButtonTapped
        case paymentCompleted(Result<PaymentResponseDTO, PaymentError>)
        case proceedToComplete  // 실제 완료 동작

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
                return .merge(
                    .send(.generateFilterThumbnails),
                    .send(.loadPurchaseHistory)
                )

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
                state.selectedFilter = filter  // 선택한 필터 상태 업데이트

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

                // 유료 필터 체크
                return .send(.checkPaidFilterPurchase)

            // MARK: - Payment Actions

            case .loadPurchaseHistory:
                return .run { send in
                    // 사용 가능한 유료 필터 목록 가져오기
                    let availableFilters = await PurchaseManager.shared.getAvailableFilters()
                    availableFilters.forEach { print("   - \($0.title) (postId: \($0.id))") }

                    // 구매한 필터의 postId 추출 (각각 isPurchased 호출)
                    var purchasedPostIds: Set<String> = []
                    for filter in availableFilters {
                        if await PurchaseManager.shared.isPurchased(filter.imageFilter) {
                            purchasedPostIds.insert(filter.id)
                        }
                    }

                    await send(.purchaseHistoryLoaded(availableFilters, purchasedPostIds))
                }

            case let .purchaseHistoryLoaded(availableFilters, purchasedPostIds):
                state.availableFilters = availableFilters
                state.purchasedFilterPostIds = purchasedPostIds
                return .none

            case let .webViewCreated(webView):
                state.webView = webView

                // 결제 대기 중이면 실제 결제 시작
                if state.isProcessingPayment, let paidFilter = state.pendingPurchaseFilter {

                    // 결제 데이터 생성
                    let payment = PaymentService.shared.createPayment(
                        amount: "\(paidFilter.price)",
                        productName: paidFilter.title,
                        buyerName: "박성훈",
                        postId: paidFilter.id
                    )

                    return .run { send in
                        do {
                            // 결제 요청 + 서버 검증
                            let validated = try await PaymentService.shared.requestPayment(
                                webView: webView,
                                payment: payment,
                                postId: paidFilter.id
                            )

                            await send(.paymentCompleted(.success(validated)))
                        } catch let error as PaymentError {
                            await send(.paymentCompleted(.failure(error)))
                        } catch {
                            await send(.paymentCompleted(.failure(.validationFailed)))
                        }
                    }
                }

                return .none

            case .checkPaidFilterPurchase:
                // 적용된 필터가 유료 필터인지 확인
                let appliedFilter = state.selectedFilter

                // 유료 필터가 아니면 바로 완료
                guard appliedFilter.isPaid else {
                    return .send(.proceedToComplete)
                }

                // 이미 구매한 필터면 바로 완료
                return .run { [purchasedFilterTypes = state.purchasedFilterTypes, availableFilters = state.availableFilters] send in
                    if purchasedFilterTypes.contains(appliedFilter) {
                        await send(.proceedToComplete)
                    } else {
                        if let paidFilter = availableFilters.first(where: { $0.imageFilter == appliedFilter }) {
                            await send(.showPurchaseModal(paidFilter))
                        } else {
                            await send(.proceedToComplete)  // 일단 진행
                        }
                    }
                }

            case let .showPurchaseModal(paidFilter):
                state.pendingPurchaseFilter = paidFilter
                state.isPurchaseModalPresented = true
                state.paymentError = nil
                return .none

            case .dismissPurchaseModal:
                state.isPurchaseModalPresented = false
                state.pendingPurchaseFilter = nil
                state.paymentError = nil
                return .none

            case .purchaseButtonTapped:

                guard state.pendingPurchaseFilter != nil else {
                    return .none
                }

                // Purchase modal 닫고 결제 모드 진입
                // WebView가 생성되면 webViewCreated에서 실제 결제 시작
                state.isPurchaseModalPresented = false
                state.isProcessingPayment = true
                state.paymentError = nil

                return .none

            case let .paymentCompleted(.success(paymentDTO)):
                state.isProcessingPayment = false

                // 로컬 캐시에 구매 기록 저장
                state.purchasedFilterPostIds.insert(paymentDTO.postId)

                return .run { send in
                    await PurchaseManager.shared.markAsPurchased(postId: paymentDTO.postId)

                    // 모달 닫고 완료 진행
                    await send(.dismissPurchaseModal)
                    await send(.proceedToComplete)
                }

            case let .paymentCompleted(.failure(error)):
                state.isProcessingPayment = false
                state.paymentError = error.localizedDescription
                return .none

            case .proceedToComplete:
                // 기존 완료 로직 (이미지 합성 및 전달)
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

 // MARK: - Action Equatable Conformance
extension EditPhotoFeature.Action: Equatable {
    static func == (lhs: EditPhotoFeature.Action, rhs: EditPhotoFeature.Action) -> Bool {
        switch (lhs, rhs) {
        case (.onAppear, .onAppear),
             (.generateFilterThumbnails, .generateFilterThumbnails),
             (.filterDragEntered, .filterDragEntered),
             (.filterDragExited, .filterDragExited),
             (.filterDragCancelled, .filterDragCancelled),
             (.applyCrop, .applyCrop),
             (.resetCrop, .resetCrop),
             (.exitTextEditMode, .exitTextEditMode),
             (.deleteSelectedText, .deleteSelectedText),
             (.toggleDrawingToolCustomization, .toggleDrawingToolCustomization),
             (.drawingUndo, .drawingUndo),
             (.drawingRedo, .drawingRedo),
             (.applyDrawingToImage, .applyDrawingToImage),
             (.saveSnapshot, .saveSnapshot),
             (.undo, .undo),
             (.redo, .redo),
             (.completeButtonTapped, .completeButtonTapped),
             (.loadPurchaseHistory, .loadPurchaseHistory),
             (.checkPaidFilterPurchase, .checkPaidFilterPurchase),
             (.dismissPurchaseModal, .dismissPurchaseModal),
             (.purchaseButtonTapped, .purchaseButtonTapped),
             (.proceedToComplete, .proceedToComplete):
            return true

        case let (.editModeChanged(l), .editModeChanged(r)):
            return l == r
        case let (.filterDragStarted(l), .filterDragStarted(r)),
             let (.filterDropped(l), .filterDropped(r)),
             let (.applyFilter(l), .applyFilter(r)):
            return l == r
        case let (.filterThumbnailGenerated(lf, _), .filterThumbnailGenerated(rf, _)):
            return lf == rf  // UIImage는 무시
        case (.filterApplied(_), .filterApplied(_)):
            return true  // UIImage는 무시
        case let (.cropRectChanged(l), .cropRectChanged(r)):
            return l == r
        case let (.aspectRatioChanged(l), .aspectRatioChanged(r)):
            return l == r
        case (.cropApplied(_), .cropApplied(_)):
            return true  // UIImage는 무시
        case let (.tapImageEmptySpace(l), .tapImageEmptySpace(r)),
             let (.enterTextEditMode(l), .enterTextEditMode(r)):
            return l == r
        case let (.editExistingText(l), .editExistingText(r)),
             let (.deleteSticker(l), .deleteSticker(r)):
            return l == r
        case let (.updateEditingText(lid, lt), .updateEditingText(rid, rt)):
            return lid == rid && lt == rt
        case let (.textColorChanged(l), .textColorChanged(r)):
            return l == r
        case let (.textFontSizeChanged(l), .textFontSizeChanged(r)):
            return l == r
        case let (.textOverlayPositionChanged(lid, lp), .textOverlayPositionChanged(rid, rp)):
            return lid == rid && lp == rp
        case let (.setCanvasSize(l), .setCanvasSize(r)):
            return l == r
        case let (.drawingToolSelected(l), .drawingToolSelected(r)):
            return l == r
        case let (.drawingColorChanged(l), .drawingColorChanged(r)):
            return l == r
        case let (.drawingWidthChanged(l), .drawingWidthChanged(r)):
            return l == r
        case (.drawingChanged(_), .drawingChanged(_)):
            return true  // PKDrawing 비교는 복잡하므로 무시
        case let (.drawingUndoStatusChanged(lc, lr), .drawingUndoStatusChanged(rc, rr)):
            return lc == rc && lr == rr
        case (.drawingApplied(_), .drawingApplied(_)):
            return true  // UIImage는 무시
        case let (.addSticker(l), .addSticker(r)):
            return l == r
        case let (.selectSticker(l), .selectSticker(r)):
            return l == r
        case let (.updateStickerPosition(lid, lp), .updateStickerPosition(rid, rp)):
            return lid == rid && lp == rp
        case let (.updateStickerScale(lid, ls), .updateStickerScale(rid, rs)):
            return lid == rid && ls == rs
        case let (.updateStickerRotation(lid, la), .updateStickerRotation(rid, ra)):
            return lid == rid && la == ra
        case let (.updateStickerTransform(lid, lp, ls, la), .updateStickerTransform(rid, rp, rs, ra)):
            return lid == rid && lp == rp && ls == rs && la == ra
        case let (.delegate(l), .delegate(r)):
            return l == r
        case let (.purchaseHistoryLoaded(lf, lp), .purchaseHistoryLoaded(rf, rp)):
            return lf == rf && lp == rp
        case (.webViewCreated(_), .webViewCreated(_)):
            return true  // WKWebView는 비교 불가, 항상 true
        case let (.showPurchaseModal(l), .showPurchaseModal(r)):
            return l == r
        case let (.paymentCompleted(l), .paymentCompleted(r)):
            switch (l, r) {
            case let (.success(ls), .success(rs)):
                return ls == rs
            case let (.failure(lf), .failure(rf)):
                return lf.localizedDescription == rf.localizedDescription
            default:
                return false
            }
        default:
            return false
        }
    }
}
