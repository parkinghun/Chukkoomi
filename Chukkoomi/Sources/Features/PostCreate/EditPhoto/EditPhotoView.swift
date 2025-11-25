//
//  EditPhotoView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/18/25.
//

import SwiftUI
import ComposableArchitecture
import PencilKit

struct EditPhotoView: View {
    let store: StoreOf<EditPhotoFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            customToolbar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

            ZStack {
                previewCanvas

                // 폰트 크기 슬라이더 (텍스트 편집 모드일 때만, 우측에 표시)
                if store.isTextEditMode {
                    HStack {
                        Spacer()
                        fontSizeSlider()
                            .padding(.trailing, 10)
                    }
                }
            }

            // 선택된 편집 모드에 따른 UI 표시
            editModeContentView
                .padding(.bottom, 8)

            // 하단 탭 바 (텍스트 편집 모드가 아닐 때만 표시)
            if !store.isTextEditMode {
                editModeTabBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(isPresented: Binding(
            get: { store.isDrawingToolCustomizationPresented },
            set: { _ in store.send(.toggleDrawingToolCustomization) }
        )) {
            PenCustomizationSheet(
                selectedTool: store.selectedDrawingTool,
                currentColor: store.drawingColor,
                currentWidth: store.drawingWidth,
                onToolSelected: { tool in
                    store.send(.drawingToolSelected(tool))
                },
                onColorChanged: { color in
                    store.send(.drawingColorChanged(color))
                },
                onWidthChanged: { width in
                    store.send(.drawingWidthChanged(width))
                }
            )
        }
    }

    // MARK: - Custom Toolbar
    private var customToolbar: some View {
        HStack(spacing: 16) {
            // 뒤로가기 버튼
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
            }

            // Undo/Redo 버튼
            Button {
                store.send(.undo)
            } label: {
                AppIcon.undo
                    .font(.system(size: 20))
                    .foregroundStyle(store.canUndo ? .black : .gray.opacity(0.5))
            }
            .disabled(!store.canUndo)

            Button {
                store.send(.redo)
            } label: {
                AppIcon.redo
                    .font(.system(size: 20))
                    .foregroundStyle(store.canRedo ? .black : .gray.opacity(0.5))
            }
            .disabled(!store.canRedo)

            Spacer()

            // 완료 버튼
            if store.isTextEditMode {
                Button {
                    store.send(.exitTextEditMode)
                } label: {
                    Text("완료")
                        .foregroundStyle(.black)
                        .fontWeight(.semibold)
                }
            } else {
                Button {
                    store.send(.completeButtonTapped)
                } label: {
                    Text("완료")
                        .foregroundStyle(.black)
                        .fontWeight(.semibold)
                }
                .disabled(store.isProcessing)
            }
        }
    }

    // MARK: - Preview Canvas
    private var previewCanvas: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                Image(uiImage: store.displayImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .clipped()

                // 텍스트 편집 모드일 때 검정 반투명 오버레이
                if store.isTextEditMode {
                    Color.black.opacity(0.5)
                        .frame(width: width, height: height)
                }

                // 텍스트 모드 또는 스티커 모드일 때 탭 감지용 투명 레이어
                if (store.selectedEditMode == .text && !store.isTextEditMode) || store.selectedEditMode == .sticker {
                    Color.clear
                        .frame(width: width, height: height)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let normalizedX = value.location.x / width
                                    let normalizedY = value.location.y / height
                                    let normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                                    store.send(.tapImageEmptySpace(normalizedPosition))
                                }
                        )
                }

                // 드롭 타겟, crop overlay 등 기존 요소 그대로
                if store.isDragging {
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: width, height: height)
                }

                if store.selectedEditMode == .crop, let cropRect = store.cropRect {
                    CropOverlayView(
                        cropRect: cropRect,
                        imageSize: CGSize(width: width, height: height),
                        onCropRectChanged: { newRect in
                            store.send(.cropRectChanged(newRect))
                        }
                    )
                    .frame(width: width, height: height)
                }

                // Text Overlays (편집 모드가 아닐 때만 완료된 텍스트 표시)
                if !store.isTextEditMode {
                    ForEach(store.textOverlays.filter { !$0.text.isEmpty }) { textOverlay in
                        Text(textOverlay.text)
                            .font(.system(size: textOverlay.fontSize, weight: .bold))
                            .foregroundColor(textOverlay.color)
                            .padding(8)
                            .position(
                                x: textOverlay.position.x * width,
                                y: textOverlay.position.y * height
                            )
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // 드래그 중 실시간으로 위치 업데이트
                                        let normalizedX = value.location.x / width
                                        let normalizedY = value.location.y / height

                                        // 범위 제한 (0.0 ~ 1.0)
                                        let clampedX = min(max(normalizedX, 0.0), 1.0)
                                        let clampedY = min(max(normalizedY, 0.0), 1.0)

                                        let newPosition = CGPoint(x: clampedX, y: clampedY)
                                        store.send(.textOverlayPositionChanged(textOverlay.id, newPosition))
                                    }
                                    .onEnded { value in
                                        // 드래그 거리가 짧으면 탭으로 인식 (편집)
                                        let dragDistance = sqrt(
                                            pow(value.translation.width, 2) +
                                            pow(value.translation.height, 2)
                                        )

                                        if dragDistance < 10 {
                                            // 탭으로 인식 - 편집 모드 진입
                                            store.send(.editExistingText(textOverlay.id))
                                        }
                                    }
                            )
                    }
                }

                // 편집 중인 텍스트 (편집 모드일 때만)
                if store.isTextEditMode, let editingId = store.editingTextId,
                   let textOverlay = store.textOverlays.first(where: { $0.id == editingId }) {
                    EditableTextOverlayView(
                        text: textOverlay.text,
                        color: textOverlay.color,
                        fontSize: textOverlay.fontSize,
                        onTextChanged: { newText in
                            store.send(.updateEditingText(textOverlay.id, newText))
                        },
                        onFinishEditing: {
                            store.send(.exitTextEditMode)
                        }
                    )
                    .frame(width: width * 0.8, height: 100)
                    .position(
                        x: textOverlay.position.x * width,
                        y: textOverlay.position.y * height
                    )
                }

                // Sticker Overlays
                ForEach(store.stickers) { sticker in
                    StickerOverlayView(
                        sticker: sticker,
                        isSelected: store.selectedStickerId == sticker.id,
                        imageSize: CGSize(width: width, height: height),
                        onTransformChanged: { position, scale, rotation in
                            store.send(.updateStickerTransform(sticker.id, position, scale, rotation))
                        },
                        onTap: {
                            store.send(.selectSticker(sticker.id))
                        },
                        onDelete: {
                            store.send(.deleteSticker(sticker.id))
                        }
                    )
                }

                // Drawing Canvas (그리기 모드일 때만)
                if store.selectedEditMode == .draw {
                    DrawingCanvasView(
                        drawing: Binding(
                            get: { store.pkDrawing },
                            set: { _ in }
                        ),
                        tool: createPKTool(
                            tool: store.selectedDrawingTool,
                            color: store.drawingColor,
                            width: store.drawingWidth
                        ),
                        undoTrigger: store.undoDrawingTrigger,
                        redoTrigger: store.redoDrawingTrigger,
                        onDrawingChanged: { drawing in
                            store.send(.drawingChanged(drawing))
                        },
                        onUndoStatusChanged: { canUndo, canRedo in
                            store.send(.drawingUndoStatusChanged(canUndo: canUndo, canRedo: canRedo))
                        }
                    )
                    .frame(width: width, height: height)
                    .allowsHitTesting(true)
                }

                if store.isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .task(id: geometry.size) {
                // 캔버스 크기 설정 (DrawingCanvas와 동일한 크기)
                // geometry.size가 변경될 때마다 업데이트
                store.send(.setCanvasSize(CGSize(width: width, height: height)))
            }
        }
    }

    // MARK: - Edit Mode Content View
    @ViewBuilder
    private var editModeContentView: some View {
        switch store.selectedEditMode {
        case .filter:
            filterStrip
        case .draw:
            drawingToolbar
        case .text:
            textControlView
        case .sticker:
            stickerStrip
        case .crop:
            cropControlView
        }
    }

    // MARK: - Edit Mode Tab Bar
    private var editModeTabBar: some View {
        HStack(spacing: 0) {
            ForEach(EditPhotoFeature.EditMode.allCases) { mode in
                editModeButton(for: mode)
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Edit Mode Button
    private func editModeButton(for mode: EditPhotoFeature.EditMode) -> some View {
        Button {
            store.send(.editModeChanged(mode))
        } label: {
            VStack(spacing: 8) {
                mode.icon
                    .font(Font.system(size: 24))
                Text(mode.rawValue)
                    .font(Font.caption)
            }
            .foregroundColor(store.selectedEditMode == mode ? Color.black : Color.gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Filter Strip
    private var filterStrip: some View {
        FilterStripView(
            filterThumbnails: store.filterThumbnails,
            selectedFilter: store.selectedFilter,
            onFilterTap: { filter in
                store.send(.applyFilter(filter))
            },
            onFilterDragStart: { filter in
                store.send(.filterDragStarted(filter))
            }
        )
    }

    // MARK: - Crop Control View
    private var cropControlView: some View {
        CropControlView(
            selectedAspectRatio: store.selectedAspectRatio,
            cropRect: store.cropRect,
            onAspectRatioChanged: { ratio in
                store.send(.aspectRatioChanged(ratio))
            },
            onResetCrop: {
                store.send(.resetCrop)
            },
            onApplyCrop: {
                store.send(.applyCrop)
            }
        )
    }

    // MARK: - Font Size Slider
    private func fontSizeSlider() -> some View {
        let sliderHeight: CGFloat = 220  // 적당한 고정 크기
        let sliderWidth: CGFloat = 30   // 슬라이더 두께

        return Slider(
            value: Binding(
                get: { store.currentTextFontSize },
                set: { store.send(.textFontSizeChanged($0)) }
            ),
            in: 16...72,
            step: 1
        )
        .tint(.white)  // 슬라이더 활성화된 부분 색상
        .frame(width: sliderHeight)  // 회전 전 width = 회전 후 height
        .frame(height: sliderWidth)  // 회전 전 height = 회전 후 width
        .background(
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: sliderWidth, height: sliderHeight)
                .rotationEffect(.degrees(-90))
        )
        .rotationEffect(.degrees(-90))
        .frame(width: sliderWidth, height: sliderHeight)  // 회전 후 최종 크기 고정
    }

    // MARK: - Text Control View
    private var textControlView: some View {
        TextControlView(
            isTextEditMode: store.isTextEditMode,
            currentTextColor: store.currentTextColor,
            onColorChanged: { color in
                store.send(.textColorChanged(color))
            }
        )
    }

    // MARK: - Drawing Toolbar
    private var drawingToolbar: some View {
        DrawingToolbar(
            selectedTool: store.selectedDrawingTool,
            currentColor: store.drawingColor,
            canUndo: store.canUndoDrawing,
            canRedo: store.canRedoDrawing,
            onToolSelected: { tool in
                store.send(.drawingToolSelected(tool))
            },
            onColorTap: {
                store.send(.toggleDrawingToolCustomization)
            },
            onBrushTap: {
                store.send(.toggleDrawingToolCustomization)
            },
            onUndo: {
                store.send(.drawingUndo)
            },
            onRedo: {
                store.send(.drawingRedo)
            }
        )
        .frame(height: 60)
    }

    // MARK: - Sticker Strip
    private var stickerStrip: some View {
        StickerStripView(
            availableStickers: store.availableStickers,
            onStickerTap: { stickerName in
                store.send(.addSticker(stickerName))
            }
        )
    }

    // MARK: - Placeholder View
    private func placeholderView(for mode: EditPhotoFeature.EditMode) -> some View {
        VStack(spacing: 16) {
            mode.icon
                .font(Font.system(size: 48))
                .foregroundColor(Color.gray)
            Text("\(mode.rawValue) 기능은 준비 중입니다")
                .font(Font.subheadline)
                .foregroundColor(Color.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper: Create PencilKit Tool
    private func createPKTool(
        tool: EditPhotoFeature.DrawingTool,
        color: Color,
        width: CGFloat
    ) -> PKTool {
        if tool == .eraser {
            return PKEraserTool(.bitmap)
        } else {
            return PKInkingTool(
                tool.pkTool,
                color: UIColor(color),
                width: width
            )
        }
    }
}

// MARK: - ImageFilter Transferable
extension ImageFilter: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .imageFilter)
    }
}

// MARK: - Custom UTType
import UniformTypeIdentifiers

extension UTType {
    static var imageFilter: UTType {
        UTType(exportedAs: "com.chukkoomi.imagefilter")
    }
}

#Preview {
    NavigationStack {
        EditPhotoView(
            store: Store(
                initialState: EditPhotoFeature.State(
                    originalImage: UIImage(systemName: "photo")!
                )
            ) {
                EditPhotoFeature()
            }
        )
    }
}
