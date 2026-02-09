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

    typealias DrawingTool = DrawingFeature.DrawingTool
    typealias CropAspectRatio = CropFeature.AspectRatio
    typealias TextOverlay = TextEditFeature.TextOverlay
    typealias StickerOverlay = StickerFeature.StickerOverlay

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
        let canvasSize: CGSize  // Drawing 좌표계를 올바르게 복원하기 위해 필요

        static func == (lhs: EditSnapshot, rhs: EditSnapshot) -> Bool {
            return lhs.selectedFilter == rhs.selectedFilter &&
                   lhs.textOverlays == rhs.textOverlays &&
                   lhs.stickers == rhs.stickers &&
                   lhs.cropRect == rhs.cropRect &&
                   lhs.selectedAspectRatio == rhs.selectedAspectRatio &&
                   lhs.pkDrawing.dataRepresentation() == rhs.pkDrawing.dataRepresentation() &&
                   lhs.canvasSize == rhs.canvasSize
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

        var filter: FilterFeature.State
        var crop: CropFeature.State
        var text: TextEditFeature.State
        var drawing: DrawingFeature.State
        var sticker: StickerFeature.State

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
        var containerSize: CGSize = .zero  // 화면 컨테이너 크기 (Drawing 좌표계 변환에 필요)

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
            self.text = TextEditFeature.State()
            self.drawing = DrawingFeature.State()
            self.sticker = StickerFeature.State()
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
                textOverlays: text.textOverlays,
                stickers: sticker.stickers,
                cropRect: crop.cropRect,
                selectedAspectRatio: crop.selectedAspectRatio,
                pkDrawing: drawing.pkDrawing,
                canvasSize: drawing.canvasSize
            )
        }

        // 스냅샷으로부터 메타데이터 복원 (displayImage는 별도 재생성)
        mutating func restoreMetadataFromSnapshot(_ snapshot: EditSnapshot) {
            // displayImage는 복원하지 않음 (캐시에서 재생성 필요)
            filter.selectedFilter = snapshot.selectedFilter
            text.textOverlays = snapshot.textOverlays
            sticker.stickers = snapshot.stickers
            crop.cropRect = snapshot.cropRect
            crop.selectedAspectRatio = snapshot.selectedAspectRatio
            drawing.pkDrawing = snapshot.pkDrawing
            drawing.canvasSize = snapshot.canvasSize
        }
    }

    // MARK: - Action
    enum Action {
        case onAppear
        case editModeChanged(EditMode)

        case filter(FilterFeature.Action)
        case applyFilter(ImageFilter)  // FilterFeature delegate로부터 호출
        case filterApplied(UIImage)

        case crop(CropFeature.Action)
        case cropApplied(UIImage)

        case text(TextEditFeature.Action)
        case tapImageEmptySpace(CGPoint)  // 이미지 빈 공간 탭 (터치 위치) - 텍스트/스티커 모드 공통

        case drawing(DrawingFeature.Action)
        case drawingApplied(UIImage)

        case sticker(StickerFeature.Action)

        // Undo/Redo Actions
        case saveSnapshot
        case undo
        case redo
        case rebuildDisplayImage(includeDrawing: Bool)  // 현재 상태로 이미지 재생성
        case imageRegenerated(UIImage)  // 재생성된 이미지 적용

        // Common
        case setContainerSize(CGSize)  // 화면 컨테이너 크기 설정
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

    // MARK: - Cancellation IDs
    private enum CancelID {
        case applyFilter
        case regenerateImage
        case applyDrawing
        case completeImage
    }

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

                // 다른 모드로 전환 시 텍스트 편집 모드 종료
                if mode != .text && state.text.isTextEditMode {
                    return .merge(
                        .send(.text(.exitTextEditMode)),
                        .run { send in
                            await send(.editModeChanged(mode))
                        }
                    )
                }

                state.selectedEditMode = mode

                // Crop 모드로 전환 시
                if mode == .crop {
                    if wasDrawingMode {
                        return .merge(
                            .send(.crop(.enterCropMode)),
                            .send(.rebuildDisplayImage(includeDrawing: true))
                        )
                    }
                    return .send(.crop(.enterCropMode))
                }

                // 그리기 모드 진입/이탈 시 displayImage 재생성
                if mode == .draw {
                    return .send(.rebuildDisplayImage(includeDrawing: false))
                }
                if wasDrawingMode && mode != .draw {
                    return .send(.rebuildDisplayImage(includeDrawing: true))
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
                    .send(.rebuildDisplayImage(includeDrawing: state.selectedEditMode != .draw))
                )

            case .filterApplied:
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
                // Crop은 파괴적 작업이므로 기존 drawing은 초기화
                state.drawing.pkDrawing = PKDrawing()
                state.isProcessing = false

                // Crop 후에는 필터 캐시 클리어 (원본이 바뀌었으므로)
                filterCache.clearFullImageCache()
                print("[Crop] Filter cache cleared (original image changed)")
                return .none

            // MARK: - Text Actions (Delegate Handling)
            case .text(.delegate(.overlaysChanged)):
                // textOverlays가 변경됨 - 이미 TextEditFeature 내부에서 처리됨
                return .none

            case .text(.delegate(.editModeChanged)):
                // 편집 모드 상태가 변경됨 - 이미 TextEditFeature 내부에서 처리됨
                return .none

            case .text(.delegate(.settingsChanged)):
                // 현재 설정이 변경됨 - 이미 TextEditFeature 내부에서 처리됨
                return .none

            case .text:
                // 다른 text 액션은 자동 처리
                return .none

            case let .tapImageEmptySpace(position):
                // 스티커 모드일 때는 스티커 선택 해제
                if state.selectedEditMode == .sticker {
                    return .send(.sticker(.deselectSticker))
                }

                // 텍스트 모드가 아니면 무시
                guard state.selectedEditMode == .text else { return .none }
                // 이미 편집 모드면 무시
                guard !state.text.isTextEditMode else { return .none }

                // 히스토리에 저장
                let snapshot = state.createSnapshot()
                state.historyStack.append(snapshot)
                if state.historyStack.count > state.maxHistorySize {
                    state.historyStack.removeFirst()
                }
                state.redoStack.removeAll()

                return .send(.text(.enterTextEditMode(position)))

            // MARK: - Drawing Actions (Delegate Handling)
            case .drawing(.delegate):
                // Drawing delegate 액션 처리
                return .none

            case .drawing:
                // 다른 drawing 액션은 자동 처리
                return .none

            case let .drawingApplied(image):
                state.displayImage = image
                state.isProcessing = false
                return .none

            // MARK: - Sticker Actions (Delegate Handling)
            case .sticker(.delegate):
                // Sticker delegate 액션 처리
                return .none

            case .sticker:
                // 다른 sticker 액션은 자동 처리
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

                // 텍스트 편집 모드 종료 (TextEditFeature에게 알림)
                if state.text.isTextEditMode {
                    return .merge(
                        .send(.text(.exitTextEditMode)),
                        .send(.rebuildDisplayImage(includeDrawing: state.selectedEditMode != .draw))
                    )
                }

                // 이미지 재생성 트리거
                return .send(.rebuildDisplayImage(includeDrawing: state.selectedEditMode != .draw))

            case .redo:
                guard !state.redoStack.isEmpty else { return .none }

                // 현재 상태를 히스토리에 저장
                let currentSnapshot = state.createSnapshot()
                state.historyStack.append(currentSnapshot)

                // Redo 스택에서 다음 상태 복원
                let nextSnapshot = state.redoStack.removeLast()
                state.restoreMetadataFromSnapshot(nextSnapshot)

                // 텍스트 편집 모드 종료 (TextEditFeature에게 알림)
                if state.text.isTextEditMode {
                    return .merge(
                        .send(.text(.exitTextEditMode)),
                        .send(.rebuildDisplayImage(includeDrawing: state.selectedEditMode != .draw))
                    )
                }

                // 이미지 재생성 트리거
                return .send(.rebuildDisplayImage(includeDrawing: state.selectedEditMode != .draw))

            case let .setContainerSize(size):
                state.containerSize = size
                return .none

            case .completeButtonTapped:
                // 텍스트 편집 모드면 먼저 종료
                if state.text.isTextEditMode {
                    return .merge(
                        .send(.text(.exitTextEditMode)),
                        .run { send in
                            await send(.checkPaidFilterPurchase)
                        }
                    )
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
                    textOverlays = state.text.textOverlays,
                    stickers = state.sticker.stickers,
                    drawing = state.drawing.pkDrawing,
                    canvasSize = state.drawing.canvasSize,
                    containerSize = state.containerSize
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
                        canvasSize: canvasSize,
                        containerSize: containerSize
                    )

                    guard let imageData = finalImage.jpegData(compressionQuality: 0.8) else {
                        return
                    }

                    // delegate로 전달 (dismiss는 부모에서 처리)
                    await send(.delegate(.didCompleteEditing(imageData)))
                }

            // MARK: - Image Regeneration (현재 상태 기준)
            case let .rebuildDisplayImage(includeDrawing):
                state.isProcessing = true

                return .run { [
                    originalImage = state.originalImage,
                    selectedFilter = state.filter.selectedFilter,
                    drawing = state.drawing.pkDrawing,
                    canvasSize = state.drawing.canvasSize,
                    containerSize = state.containerSize,
                    filterCache
                ] send in
                    // 1. 필터 적용 (캐시 우선)
                    var baseImage = originalImage
                    let filterKey = selectedFilter.rawValue

                    if let cachedImage = filterCache.getFullImage(filterKey) {
                        print("[Cache HIT] Filter '\(filterKey)' from cache")
                        baseImage = cachedImage
                    } else {
                        print("[Cache MISS] Applying filter '\(filterKey)'")
                        if let filteredImage = selectedFilter.apply(to: originalImage) {
                            baseImage = filteredImage
                            filterCache.setFullImage(filteredImage, filterKey)
                        }
                    }

                    // 2. 그리기 합성 (필요 시)
                    if includeDrawing, !drawing.strokes.isEmpty {
                        let composited = await ImageEditHelper.compositeImageWithDrawing(
                            baseImage: baseImage,
                            drawing: drawing,
                            canvasSize: canvasSize,
                            containerSize: containerSize
                        )
                        await send(.imageRegenerated(composited))
                    } else {
                        await send(.imageRegenerated(baseImage))
                    }
                }
                .cancellable(id: CancelID.regenerateImage, cancelInFlight: true)

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

        Scope(state: \.text, action: \.text) {
            TextEditFeature()
        }

        Scope(state: \.drawing, action: \.drawing) {
            DrawingFeature()
        }

        Scope(state: \.sticker, action: \.sticker) {
            StickerFeature()
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
             (.saveSnapshot, .saveSnapshot),
             (.undo, .undo),
             (.redo, .redo),
             (.completeButtonTapped, .completeButtonTapped),
             (.memoryWarning, .memoryWarning),
             (.loadPurchaseHistory, .loadPurchaseHistory),
             (.checkPaidFilterPurchase, .checkPaidFilterPurchase),
             (.proceedToComplete, .proceedToComplete):
            return true
        case let (.setContainerSize(l), .setContainerSize(r)):
            return l == r

        case let (.editModeChanged(l), .editModeChanged(r)):
            return l == r
        case let (.filter(l), .filter(r)):
            return l == r
        case let (.applyFilter(l), .applyFilter(r)):
            return l == r
        case (.filterApplied(_), .filterApplied(_)),
             (.imageRegenerated(_), .imageRegenerated(_)):
            return true  // UIImage는 무시
        case let (.rebuildDisplayImage(l), .rebuildDisplayImage(r)):
            return l == r
        case let (.crop(l), .crop(r)):
            return l == r
        case (.cropApplied(_), .cropApplied(_)):
            return true  // UIImage는 무시
        case let (.text(l), .text(r)):
            return l == r
        case let (.tapImageEmptySpace(l), .tapImageEmptySpace(r)):
            return l == r
        case let (.drawing(l), .drawing(r)):
            return l == r
        case (.drawingApplied(_), .drawingApplied(_)):
            return true  // UIImage는 무시
        case let (.sticker(l), .sticker(r)):
            return l == r
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
