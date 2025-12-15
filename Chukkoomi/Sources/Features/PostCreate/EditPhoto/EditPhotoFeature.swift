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

    // CropAspectRatio는 CropFeature.AspectRatio로 대체됨 (타입 별칭 유지)
    typealias CropAspectRatio = CropFeature.AspectRatio

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
    /// 메타데이터만 저장하는 경량 스냅샷
    /// - displayImage는 저장하지 않고, 필요 시 캐시에서 재생성
    struct EditSnapshot: Equatable {
        // displayImage 제거 (메모리 절약)
        let selectedFilter: ImageFilter
        let textOverlays: [TextOverlay]
        let stickers: [StickerOverlay]
        let cropRect: CGRect?
        let selectedAspectRatio: CropAspectRatio
        let pkDrawing: PKDrawing

        static func == (lhs: EditSnapshot, rhs: EditSnapshot) -> Bool {
            return lhs.selectedFilter == rhs.selectedFilter &&
                   lhs.textOverlays == rhs.textOverlays &&
                   lhs.stickers == rhs.stickers &&
                   lhs.cropRect == rhs.cropRect &&
                   lhs.selectedAspectRatio == rhs.selectedAspectRatio &&
                   lhs.pkDrawing.dataRepresentation() == rhs.pkDrawing.dataRepresentation()
        }
    }

    // MARK: - CropSnapshot
    /// Crop 작업은 파괴적이므로 원본 이미지를 별도 저장
    struct CropSnapshot: Equatable {
        let beforeCropImage: UIImage  // Crop 전 이미지
        let originalImage: UIImage    // 최초 원본 이미지
        let timestamp: Date

        static func == (lhs: CropSnapshot, rhs: CropSnapshot) -> Bool {
            // UIImage는 참조 비교
            return lhs.beforeCropImage === rhs.beforeCropImage &&
                   lhs.originalImage === rhs.originalImage &&
                   lhs.timestamp == rhs.timestamp
        }
    }

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var originalImage: UIImage
        var displayImage: UIImage  // 현재 화면에 표시되는 이미지
        var selectedEditMode: EditMode = .filter  // 기본값: 필터

        // Filter (Child Feature)
        var filter: FilterFeature.State

        // Crop (Child Feature)
        var crop: CropFeature.State

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
        var maxHistorySize: Int = 10  // 메모리 최적화: 20 → 10으로 축소

        // Crop History (파괴적 작업이므로 별도 관리)
        var cropHistory: [CropSnapshot] = []
        var maxCropHistorySize: Int = 3  // Crop은 이미지 저장이 필요하므로 최소화

        // Common
        var isProcessing: Bool = false
        var isDragging: Bool = false

        // Payment (결제 관련) - Child Feature로 분리
        @Presents var paidFilterPurchase: PaidFilterPurchaseFeature.State?
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
            self.filter = FilterFeature.State(originalImage: originalImage)
            self.crop = CropFeature.State()
        }

        // Undo/Redo 가능 여부 계산
        var canUndo: Bool {
            !historyStack.isEmpty
        }

        var canRedo: Bool {
            !redoStack.isEmpty
        }

        // 현재 상태의 스냅샷 생성 (메타데이터만)
        func createSnapshot() -> EditSnapshot {
            EditSnapshot(
                selectedFilter: filter.selectedFilter,
                textOverlays: textOverlays,
                stickers: stickers,
                cropRect: crop.cropRect,
                selectedAspectRatio: crop.selectedAspectRatio,
                pkDrawing: pkDrawing
            )
        }

        // 스냅샷으로부터 메타데이터 복원 (displayImage는 별도 재생성)
        mutating func restoreMetadataFromSnapshot(_ snapshot: EditSnapshot) {
            // displayImage는 복원하지 않음 (캐시에서 재생성 필요)
            filter.selectedFilter = snapshot.selectedFilter
            textOverlays = snapshot.textOverlays
            stickers = snapshot.stickers
            crop.cropRect = snapshot.cropRect
            crop.selectedAspectRatio = snapshot.selectedAspectRatio
            pkDrawing = snapshot.pkDrawing
        }
    }

    // MARK: - Action
    enum Action {
        case onAppear
        case editModeChanged(EditMode)

        // Filter Actions (Child Feature)
        case filter(FilterFeature.Action)
        case applyFilter(ImageFilter)  // FilterFeature delegate로부터 호출
        case filterApplied(UIImage)

        // Crop Actions (Child Feature)
        case crop(CropFeature.Action)
        case cropApplied(UIImage)

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
        case regenerateImageFromSnapshot(EditSnapshot)  // 스냅샷으로부터 이미지 재생성
        case imageRegenerated(UIImage)  // 재생성된 이미지 적용

        // Common
        case completeButtonTapped
        case memoryWarning  // 메모리 경고 처리
        case delegate(Delegate)

        // Payment Actions
        case loadPurchaseHistory
        case purchaseHistoryLoaded([PaidFilter], Set<String>)  // availableFilters, purchasedPostIds
        case checkPaidFilterPurchase  // 유료 필터 구매 확인
        case paidFilterPurchase(PresentationAction<PaidFilterPurchaseFeature.Action>)
        case proceedToComplete  // 실제 완료 동작

        enum Delegate: Equatable {
            case didCompleteEditing(Data)
        }
    }

    // MARK: - Dependencies
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.filterCache) var filterCache
    @Dependency(\.payment) var payment
    @Dependency(\.purchase) var purchase

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.filter(.onAppear)),
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

                // Crop 모드로 전환 시
                if mode == .crop {
                    return .send(.crop(.enterCropMode))
                }

                // 그리기 모드를 벗어날 때 drawing 적용
                if isLeavingDrawingMode && hasDrawing {
                    return .send(.applyDrawingToImage)
                }

                return .none

            // MARK: - Filter Actions (Delegate Handling)
            case .filter(.delegate(.filterChanged(let filter))):
                // FilterFeature에서 필터가 변경됨 - 실제 필터 적용
                return .send(.applyFilter(filter))

            case .filter(.delegate(.previewFilterChanged(let previewFilter))):
                // 드래그 중 프리뷰 필터 변경
                if let previewFilter = previewFilter {
                    return .send(.applyFilter(previewFilter))
                } else {
                    // 프리뷰 취소 - 원래 선택된 필터로 복원
                    return .send(.applyFilter(state.filter.selectedFilter))
                }

            case .filter:
                // 다른 filter 액션은 자동 처리
                return .none

            case let .applyFilter(filter):
                state.isProcessing = true

                return .merge(
                    .send(.saveSnapshot),
                    .run { [originalImage = state.originalImage, filterCache] send in
                        let filterKey = filter.rawValue

                        // 캐시 확인
                        if let cachedImage = filterCache.getFullImage(filterKey) {
                            print("[Cache HIT] Filter '\(filterKey)' from cache")
                            await send(.filterApplied(cachedImage))
                        } else {
                            print("[Cache MISS] Applying filter '\(filterKey)'")
                            // 전체 해상도 이미지에 필터 적용
                            if let filtered = filter.apply(to: originalImage) {
                                // 캐시에 저장
                                filterCache.setFullImage(filtered, filterKey)
                                await send(.filterApplied(filtered))
                            } else {
                                await send(.filterApplied(originalImage))
                            }
                        }
                    }
                )

            case let .filterApplied(image):
                state.displayImage = image
                state.isProcessing = false
                return .none

            // MARK: - Crop Actions (Delegate Handling)
            case .crop(.delegate(.cropRectUpdated)):
                // cropRect 변경은 CropFeature 내부에서 처리됨
                return .none

            case .crop(.delegate(.applyCropRequested(let cropRect))):
                // Crop 적용 요청 받음
                state.isProcessing = true

                // Crop은 파괴적 작업이므로 CropSnapshot 저장
                let cropSnapshot = CropSnapshot(
                    beforeCropImage: state.displayImage,
                    originalImage: state.originalImage,
                    timestamp: Date()
                )
                state.cropHistory.append(cropSnapshot)

                // 최대 Crop 히스토리 크기 제한
                if state.cropHistory.count > state.maxCropHistorySize {
                    state.cropHistory.removeFirst()
                }

                return .run { [displayImage = state.displayImage] send in
                    // Crop 적용
                    if let croppedImage = await ImageEditHelper.cropImage(displayImage, to: cropRect) {
                        await send(.cropApplied(croppedImage))
                    }
                }

            case .crop:
                // 다른 crop 액션은 자동 처리
                return .none

            case let .cropApplied(image):
                state.displayImage = image
                state.originalImage = image  // 자른 이미지를 새로운 원본으로
                state.crop.cropRect = nil
                state.crop.isCropping = false
                state.isProcessing = false

                // Crop 후에는 필터 캐시 클리어 (원본이 바뀌었으므로)
                filterCache.clearFullImageCache()
                print("[Crop] ✂️ Filter cache cleared (original image changed)")
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
                state.restoreMetadataFromSnapshot(previousSnapshot)

                // 텍스트 편집 모드 종료
                state.editingTextId = nil
                state.isTextEditMode = false

                // 이미지 재생성 트리거
                return .send(.regenerateImageFromSnapshot(previousSnapshot))

            case .redo:
                guard !state.redoStack.isEmpty else { return .none }

                // 현재 상태를 히스토리에 저장
                let currentSnapshot = state.createSnapshot()
                state.historyStack.append(currentSnapshot)

                // Redo 스택에서 다음 상태 복원
                let nextSnapshot = state.redoStack.removeLast()
                state.restoreMetadataFromSnapshot(nextSnapshot)

                // 텍스트 편집 모드 종료
                state.editingTextId = nil
                state.isTextEditMode = false

                // 이미지 재생성 트리거
                return .send(.regenerateImageFromSnapshot(nextSnapshot))

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
                return .run { [purchase] send in
                    // 사용 가능한 유료 필터 목록 가져오기
                    let availableFilters = await purchase.getAvailableFilters()
                    availableFilters.forEach { print("   - \($0.title) (postId: \($0.id))") }

                    // 구매한 필터의 postId 추출 (각각 isPurchased 호출)
                    var purchasedPostIds: Set<String> = []
                    for filter in availableFilters {
                        if await purchase.isPurchased(filter.imageFilter) {
                            purchasedPostIds.insert(filter.id)
                        }
                    }

                    await send(.purchaseHistoryLoaded(availableFilters, purchasedPostIds))
                }

            case let .purchaseHistoryLoaded(availableFilters, purchasedPostIds):
                state.availableFilters = availableFilters
                state.purchasedFilterPostIds = purchasedPostIds
                return .none

            case .checkPaidFilterPurchase:
                // 적용된 필터가 유료 필터인지 확인
                let appliedFilter = state.filter.selectedFilter

                // 유료 필터가 아니면 바로 완료
                guard appliedFilter.isPaid else {
                    return .send(.proceedToComplete)
                }

                // 이미 구매한 필터면 바로 완료
                if state.purchasedFilterTypes.contains(appliedFilter) {
                    return .send(.proceedToComplete)
                }

                // 구매하지 않은 유료 필터 - PaidFilterPurchaseFeature 표시
                if let paidFilter = state.availableFilters.first(where: { $0.imageFilter == appliedFilter }) {
                    state.paidFilterPurchase = PaidFilterPurchaseFeature.State(
                        pendingFilter: paidFilter,
                        availableFilters: state.availableFilters,
                        purchasedFilterPostIds: state.purchasedFilterPostIds
                    )
                    return .none
                }

                // 필터를 찾지 못하면 일단 진행
                return .send(.proceedToComplete)

            case .paidFilterPurchase(.presented(.delegate(.purchaseCompleted(let paymentDTO)))):
                // 결제 성공 - 구매 기록 업데이트
                state.purchasedFilterPostIds.insert(paymentDTO.postId)

                // Feature 닫기
                state.paidFilterPurchase = nil

                // 완료 진행
                return .send(.proceedToComplete)

            case .paidFilterPurchase(.presented(.delegate(.purchaseCancelled))):
                // 결제 취소 - Feature 닫기
                state.paidFilterPurchase = nil
                return .none

            case .paidFilterPurchase:
                // 다른 paidFilterPurchase 액션은 자동 처리
                return .none

            case .proceedToComplete:
                // 기존 완료 로직 (이미지 합성 및 전달)
                state.isProcessing = true

                return .run { [
                    displayImage = state.displayImage,
                    cropRect = state.crop.cropRect,
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

            // MARK: - Image Regeneration (Undo/Redo용)
            case let .regenerateImageFromSnapshot(snapshot):
                // 스냅샷으로부터 이미지 재생성 (캐시 활용)
                state.isProcessing = true

                return .run { [originalImage = state.originalImage, filterCache] send in
                    // 1. 필터 적용 (캐시 우선 확인)
                    var baseImage = originalImage
                    let filterKey = snapshot.selectedFilter.rawValue

                    // FilterCache에서 확인
                    if let cachedImage = filterCache.getFullImage(filterKey) {
                        print("[Cache HIT] Filter '\(filterKey)' from cache")
                        baseImage = cachedImage
                    } else {
                        print("[Cache MISS] Applying filter '\(filterKey)'")
                        if let filteredImage = snapshot.selectedFilter.apply(to: originalImage) {
                            baseImage = filteredImage
                            // 캐시에 저장
                            filterCache.setFullImage(filteredImage, filterKey)
                        }
                    }

                    // 2. 오버레이 합성 (텍스트, 스티커, 그림)
                    // 오버레이가 있으면 합성, 없으면 베이스 이미지 그대로
                    let hasOverlays = !snapshot.textOverlays.isEmpty ||
                                      !snapshot.stickers.isEmpty ||
                                      !snapshot.pkDrawing.strokes.isEmpty

                    let finalImage: UIImage
                    if hasOverlays {
                        // 임시 canvasSize (실제 canvasSize는 State에서 가져와야 하지만 스냅샷에 없음)
                        // Drawing이 있으면 이미지 크기로 가정
                        let canvasSize = baseImage.size
                        finalImage = await ImageEditHelper.compositeImageWithOverlays(
                            baseImage: baseImage,
                            textOverlays: snapshot.textOverlays,
                            stickers: snapshot.stickers,
                            drawing: snapshot.pkDrawing,
                            canvasSize: canvasSize
                        )
                    } else {
                        finalImage = baseImage
                    }

                    await send(.imageRegenerated(finalImage))
                }

            case let .imageRegenerated(image):
                state.displayImage = image
                state.isProcessing = false
                return .none

            // MARK: - Memory Management
            case .memoryWarning:
                print("[Memory Warning] Clearing caches and limiting history")

                // 2. 히스토리 크기 축소 (10 → 5)
                if state.historyStack.count > 5 {
                    let removeCount = state.historyStack.count - 5
                    state.historyStack.removeFirst(removeCount)
                    print("   - History stack reduced: \(state.historyStack.count + removeCount) → \(state.historyStack.count)")
                }

                // 3. Redo 스택 클리어
                if !state.redoStack.isEmpty {
                    let redoCount = state.redoStack.count
                    state.redoStack.removeAll()
                    print("   - Redo stack cleared: \(redoCount) items")
                }

                // 4. Crop 히스토리 축소 (3 → 1)
                if state.cropHistory.count > 1 {
                    let cropRemoveCount = state.cropHistory.count - 1
                    state.cropHistory.removeFirst(cropRemoveCount)
                    print("   - Crop history reduced: \(state.cropHistory.count + cropRemoveCount) → \(state.cropHistory.count)")
                }

                // 1. FilterCache 정리 (전체 이미지만, 썸네일은 유지)
                filterCache.handleMemoryWarning()

                return .none

            case .delegate:
                return .none
            }
        }

        Scope(state: \.filter, action: \.filter) {
            FilterFeature()
        }

        Scope(state: \.crop, action: \.crop) {
            CropFeature()
        }

        .ifLet(\.$paidFilterPurchase, action: \.paidFilterPurchase) {
            PaidFilterPurchaseFeature()
        }
    }

}

 // MARK: - Action Equatable Conformance
extension EditPhotoFeature.Action: Equatable {
    static func == (lhs: EditPhotoFeature.Action, rhs: EditPhotoFeature.Action) -> Bool {
        switch (lhs, rhs) {
        case (.onAppear, .onAppear),
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
             (.memoryWarning, .memoryWarning),
             (.loadPurchaseHistory, .loadPurchaseHistory),
             (.checkPaidFilterPurchase, .checkPaidFilterPurchase),
             (.proceedToComplete, .proceedToComplete):
            return true

        case let (.editModeChanged(l), .editModeChanged(r)):
            return l == r
        case let (.filter(l), .filter(r)):
            return l == r
        case let (.applyFilter(l), .applyFilter(r)):
            return l == r
        case (.filterApplied(_), .filterApplied(_)),
             (.imageRegenerated(_), .imageRegenerated(_)):
            return true  // UIImage는 무시
        case (.regenerateImageFromSnapshot(_), .regenerateImageFromSnapshot(_)):
            return true  // EditSnapshot 비교는 복잡하므로 무시
        case let (.crop(l), .crop(r)):
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
        case let (.paidFilterPurchase(l), .paidFilterPurchase(r)):
            return l == r
        default:
            return false
        }
    }
}
