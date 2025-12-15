//
//  StickerFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.
//

import ComposableArchitecture
import Foundation
import SwiftUI

/// 스티커 기능을 담당하는 Feature
@Reducer
struct StickerFeature {

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

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        /// 스티커 목록
        var stickers: [StickerOverlay] = []

        /// 선택된 스티커 ID
        var selectedStickerId: UUID?

        /// 사용 가능한 스티커 목록
        var availableStickers: [String] = (1...13).map { "sticker_\($0)" }

        init() {}
    }

    // MARK: - Action
    enum Action: Equatable {
        /// 스티커 추가
        case addSticker(String)

        /// 스티커 선택/해제
        case selectSticker(UUID?)

        /// 스티커 위치 업데이트
        case updateStickerPosition(UUID, CGPoint)

        /// 스티커 크기 업데이트
        case updateStickerScale(UUID, CGFloat)

        /// 스티커 회전 업데이트
        case updateStickerRotation(UUID, Angle)

        /// 스티커 변형 업데이트 (위치+크기+회전)
        case updateStickerTransform(UUID, CGPoint, CGFloat, Angle)

        /// 스티커 삭제
        case deleteSticker(UUID)

        /// 빈 공간 탭 (선택 해제)
        case deselectSticker

        /// Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            /// 스티커 목록이 변경됨
            case stickersChanged([StickerOverlay])
        }
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .addSticker(imageName):
                // 새 스티커 추가 (중앙에 배치)
                let newSticker = StickerOverlay(imageName: imageName)
                state.stickers.append(newSticker)
                // 자동 선택하지 않음 - 사용자가 직접 탭해야 선택됨
                return .send(.delegate(.stickersChanged(state.stickers)))

            case let .selectSticker(stickerId):
                state.selectedStickerId = stickerId
                return .none

            case let .updateStickerPosition(id, position):
                if let index = state.stickers.firstIndex(where: { $0.id == id }) {
                    state.stickers[index].position = position
                    return .send(.delegate(.stickersChanged(state.stickers)))
                }
                return .none

            case let .updateStickerScale(id, scale):
                if let index = state.stickers.firstIndex(where: { $0.id == id }) {
                    state.stickers[index].scale = scale
                    return .send(.delegate(.stickersChanged(state.stickers)))
                }
                return .none

            case let .updateStickerRotation(id, rotation):
                if let index = state.stickers.firstIndex(where: { $0.id == id }) {
                    state.stickers[index].rotation = rotation
                    return .send(.delegate(.stickersChanged(state.stickers)))
                }
                return .none

            case let .updateStickerTransform(id, position, scale, rotation):
                if let index = state.stickers.firstIndex(where: { $0.id == id }) {
                    state.stickers[index].position = position
                    state.stickers[index].scale = scale
                    state.stickers[index].rotation = rotation
                    return .send(.delegate(.stickersChanged(state.stickers)))
                }
                return .none

            case let .deleteSticker(id):
                state.stickers.removeAll(where: { $0.id == id })
                if state.selectedStickerId == id {
                    state.selectedStickerId = nil
                }
                return .send(.delegate(.stickersChanged(state.stickers)))

            case .deselectSticker:
                state.selectedStickerId = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
