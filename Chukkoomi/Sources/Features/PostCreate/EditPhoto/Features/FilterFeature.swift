//
//  FilterFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.
//

import ComposableArchitecture
import Foundation
import UIKit

/// 이미지 필터 선택 및 관리를 담당하는 Feature
@Reducer
struct FilterFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        /// 현재 선택된 필터
        var selectedFilter: ImageFilter = .original

        /// 드래그 중인 필터 (라이브 프리뷰)
        var previewFilter: ImageFilter?

        /// 필터 썸네일 이미지들
        var filterThumbnails: [ImageFilter: UIImage] = [:]

        /// 드래그 중 여부
        var isDragging: Bool = false

        /// 처리 중 여부 (썸네일 생성)
        var isProcessing: Bool = false

        /// 썸네일 생성용 원본 이미지
        var originalImage: UIImage

        init(originalImage: UIImage) {
            self.originalImage = originalImage
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        /// 뷰 로드 시 (썸네일 생성 트리거)
        case onAppear

        /// 썸네일 생성 시작
        case generateThumbnails

        /// 썸네일 생성 완료
        case thumbnailGenerated(ImageFilter, UIImage)

        /// 드래그 시작
        case dragStarted(ImageFilter)

        /// Preview Canvas 위로 드래그 진입
        case dragEntered

        /// Preview Canvas에서 벗어남
        case dragExited

        /// 필터 드롭 (적용)
        case dropped(ImageFilter)

        /// 드래그 취소
        case dragCancelled

        /// 필터 직접 선택 (탭)
        case selectFilter(ImageFilter)

        /// Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            /// 필터가 변경됨 (부모에게 알림)
            case filterChanged(ImageFilter)

            /// 프리뷰 필터가 변경됨 (드래그 중)
            case previewFilterChanged(ImageFilter?)
        }
    }

    // MARK: - Dependencies
    @Dependency(\.filterCache) var filterCache

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 썸네일이 없으면 생성
                guard state.filterThumbnails.isEmpty else {
                    return .none
                }
                return .send(.generateThumbnails)

            case .generateThumbnails:
                state.isProcessing = true

                return .run { [originalImage = state.originalImage] send in
                    // 썸네일용 작은 이미지 생성 (성능 최적화)
                    let thumbnailSize = CGSize(width: 100, height: 100)
                    let thumbnailImage = await ImageEditHelper.resizeImage(originalImage, to: thumbnailSize)

                    // 각 필터별 썸네일 생성
                    for filter in ImageFilter.allCases {
                        if let filtered = filter.apply(to: thumbnailImage) {
                            await send(.thumbnailGenerated(filter, filtered))
                        }
                    }
                }

            case let .thumbnailGenerated(filter, thumbnail):
                state.filterThumbnails[filter] = thumbnail
                // 모든 썸네일이 생성되면 processing 완료
                if state.filterThumbnails.count == ImageFilter.allCases.count {
                    state.isProcessing = false
                }
                return .none

            case let .dragStarted(filter):
                state.isDragging = true
                state.previewFilter = filter
                return .send(.delegate(.previewFilterChanged(filter)))

            case .dragEntered:
                // 드래그가 Preview Canvas 위로 진입
                // 현재 previewFilter로 미리보기
                if let previewFilter = state.previewFilter {
                    return .send(.delegate(.previewFilterChanged(previewFilter)))
                }
                return .none

            case .dragExited:
                // Preview Canvas에서 벗어남 - 프리뷰 취소
                state.previewFilter = nil
                return .send(.delegate(.previewFilterChanged(nil)))

            case let .dropped(filter):
                state.isDragging = false
                state.previewFilter = nil
                state.selectedFilter = filter
                // 드롭된 필터를 최종 적용
                return .send(.delegate(.filterChanged(filter)))

            case .dragCancelled:
                state.isDragging = false
                state.previewFilter = nil
                // 프리뷰 취소
                return .send(.delegate(.previewFilterChanged(nil)))

            case let .selectFilter(filter):
                state.selectedFilter = filter
                return .send(.delegate(.filterChanged(filter)))

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Action Equatable Conformance
extension FilterFeature.Action {
    static func == (lhs: FilterFeature.Action, rhs: FilterFeature.Action) -> Bool {
        switch (lhs, rhs) {
        case (.onAppear, .onAppear),
             (.generateThumbnails, .generateThumbnails),
             (.dragEntered, .dragEntered),
             (.dragExited, .dragExited),
             (.dragCancelled, .dragCancelled):
            return true
        case let (.thumbnailGenerated(lf, _), .thumbnailGenerated(rf, _)):
            return lf == rf  // UIImage는 무시
        case let (.dragStarted(l), .dragStarted(r)),
             let (.dropped(l), .dropped(r)),
             let (.selectFilter(l), .selectFilter(r)):
            return l == r
        case let (.delegate(l), .delegate(r)):
            return l == r
        default:
            return false
        }
    }
}
