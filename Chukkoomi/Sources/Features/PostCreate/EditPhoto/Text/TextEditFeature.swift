//
//  TextEditFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.
//

import ComposableArchitecture
import Foundation
import SwiftUI

/// 텍스트 편집 기능을 담당하는 Feature
@Reducer
struct TextEditFeature {

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

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        /// 텍스트 오버레이 목록
        var textOverlays: [TextOverlay] = []

        /// 현재 편집 중인 텍스트 ID
        var editingTextId: UUID?

        /// 텍스트 편집 모드 활성화 여부
        var isTextEditMode: Bool = false

        /// 현재 텍스트 색상
        var currentTextColor: Color = .white

        /// 현재 텍스트 폰트 크기
        var currentTextFontSize: CGFloat = 32

        init() {}
    }

    // MARK: - Action
    enum Action: Equatable {
        /// 텍스트 편집 모드 진입 (새 텍스트, 터치 위치)
        case enterTextEditMode(CGPoint)

        /// 기존 텍스트 편집 (수정)
        case editExistingText(UUID)

        /// 텍스트 편집 모드 종료
        case exitTextEditMode

        /// 편집 중 텍스트 업데이트
        case updateEditingText(UUID, String)

        /// 텍스트 색상 변경
        case textColorChanged(Color)

        /// 텍스트 폰트 크기 변경
        case textFontSizeChanged(CGFloat)

        /// 텍스트 오버레이 위치 변경
        case textOverlayPositionChanged(UUID, CGPoint)

        /// 선택된 텍스트 삭제
        case deleteSelectedText

        /// Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            /// 텍스트 오버레이 목록이 변경됨
            case overlaysChanged([TextOverlay])

            /// 편집 모드 상태가 변경됨
            case editModeChanged(isEditing: Bool, editingId: UUID?)

            /// 현재 설정이 변경됨 (색상, 폰트 크기)
            case settingsChanged(color: Color, fontSize: CGFloat)
        }
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .enterTextEditMode(position):
                // 텍스트 편집 모드 활성화
                state.isTextEditMode = true

                // 터치한 위치에 새 텍스트 생성
                let newOverlay = TextOverlay(
                    text: "",
                    position: position,
                    color: state.currentTextColor,
                    fontSize: state.currentTextFontSize
                )
                state.textOverlays.append(newOverlay)
                state.editingTextId = newOverlay.id

                return .merge(
                    .send(.delegate(.overlaysChanged(state.textOverlays))),
                    .send(.delegate(.editModeChanged(isEditing: true, editingId: newOverlay.id)))
                )

            case let .editExistingText(id):
                // 텍스트 편집 모드 활성화
                state.isTextEditMode = true
                state.editingTextId = id

                if let overlay = state.textOverlays.first(where: { $0.id == id }) {
                    state.currentTextColor = overlay.color
                    state.currentTextFontSize = overlay.fontSize
                }

                return .merge(
                    .send(.delegate(.editModeChanged(isEditing: true, editingId: id))),
                    .send(.delegate(.settingsChanged(color: state.currentTextColor, fontSize: state.currentTextFontSize)))
                )

            case let .updateEditingText(id, text):
                // 편집 중 텍스트 업데이트
                if let index = state.textOverlays.firstIndex(where: { $0.id == id }) {
                    state.textOverlays[index].text = text
                    return .send(.delegate(.overlaysChanged(state.textOverlays)))
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

                return .merge(
                    .send(.delegate(.overlaysChanged(state.textOverlays))),
                    .send(.delegate(.editModeChanged(isEditing: false, editingId: nil)))
                )

            case let .textColorChanged(color):
                state.currentTextColor = color

                // 편집 중인 텍스트가 있으면 색상 업데이트
                if let editingId = state.editingTextId,
                   let index = state.textOverlays.firstIndex(where: { $0.id == editingId }) {
                    state.textOverlays[index].color = color
                    return .merge(
                        .send(.delegate(.overlaysChanged(state.textOverlays))),
                        .send(.delegate(.settingsChanged(color: color, fontSize: state.currentTextFontSize)))
                    )
                }

                return .send(.delegate(.settingsChanged(color: color, fontSize: state.currentTextFontSize)))

            case let .textFontSizeChanged(size):
                state.currentTextFontSize = size

                // 편집 중인 텍스트가 있으면 크기 업데이트
                if let editingId = state.editingTextId,
                   let index = state.textOverlays.firstIndex(where: { $0.id == editingId }) {
                    state.textOverlays[index].fontSize = size
                    return .merge(
                        .send(.delegate(.overlaysChanged(state.textOverlays))),
                        .send(.delegate(.settingsChanged(color: state.currentTextColor, fontSize: size)))
                    )
                }

                return .send(.delegate(.settingsChanged(color: state.currentTextColor, fontSize: size)))

            case let .textOverlayPositionChanged(id, position):
                if let index = state.textOverlays.firstIndex(where: { $0.id == id }) {
                    state.textOverlays[index].position = position
                    return .send(.delegate(.overlaysChanged(state.textOverlays)))
                }
                return .none

            case .deleteSelectedText:
                guard let editingId = state.editingTextId else { return .none }

                // 텍스트 삭제
                state.textOverlays.removeAll(where: { $0.id == editingId })
                state.editingTextId = nil

                return .send(.delegate(.overlaysChanged(state.textOverlays)))

            case .delegate:
                return .none
            }
        }
    }
}
