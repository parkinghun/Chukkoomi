//
//  CropFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.
//

import ComposableArchitecture
import Foundation
import CoreGraphics

/// 이미지 자르기 기능을 담당하는 Feature
@Reducer
struct CropFeature {

    // MARK: - AspectRatio
    enum AspectRatio: String, CaseIterable, Identifiable {
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

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        /// 자를 영역 (normalized 0.0~1.0)
        var cropRect: CGRect?

        /// 선택된 가로세로 비율
        var selectedAspectRatio: AspectRatio = .free

        /// 자르기 모드 활성화 여부
        var isCropping: Bool = false

        init(cropRect: CGRect? = nil) {
            self.cropRect = cropRect
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        /// Crop 모드 진입
        case enterCropMode

        /// Crop 영역 변경
        case cropRectChanged(CGRect)

        /// 가로세로 비율 변경
        case aspectRatioChanged(AspectRatio)

        /// Crop 적용 (부모에게 요청)
        case applyCrop

        /// Crop 리셋 (전체 이미지로)
        case reset

        /// Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            /// Crop 영역이 변경됨
            case cropRectUpdated(CGRect?)

            /// Crop 적용 요청
            case applyCropRequested(CGRect)
        }
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .enterCropMode:
                // Crop 모드 진입 시 초기 cropRect 설정 (전체 이미지)
                if state.cropRect == nil {
                    state.cropRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
                }
                state.isCropping = true
                return .send(.delegate(.cropRectUpdated(state.cropRect)))

            case let .cropRectChanged(rect):
                state.cropRect = rect
                return .send(.delegate(.cropRectUpdated(rect)))

            case let .aspectRatioChanged(ratio):
                state.selectedAspectRatio = ratio
                // 전체 이미지 크기에서 선택한 비율로 cropRect 계산
                if let aspectRatio = ratio.ratio {
                    state.cropRect = ImageEditHelper.calculateCropRectForAspectRatio(aspectRatio)
                } else {
                    // free 비율인 경우 전체 이미지로
                    state.cropRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
                }
                return .send(.delegate(.cropRectUpdated(state.cropRect)))

            case .applyCrop:
                guard let cropRect = state.cropRect else { return .none }
                return .send(.delegate(.applyCropRequested(cropRect)))

            case .reset:
                // 전체 이미지로 리셋
                state.cropRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
                state.selectedAspectRatio = .free
                return .send(.delegate(.cropRectUpdated(state.cropRect)))

            case .delegate:
                return .none
            }
        }
    }
}
