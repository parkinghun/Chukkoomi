//
//  EditVideoFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import ComposableArchitecture
import Foundation
import Photos
import AVFoundation

@Reducer
struct EditVideoFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        let videoAsset: PHAsset
        var isPlaying: Bool = false
        var currentTime: Double = 0.0
        var duration: Double = 0.0
        var seekTrigger: SeekDirection? = nil

        // 편집 데이터
        var editState: EditState = EditState()

        // 필터 적용 상태
        var isApplyingFilter: Bool = false

        // 내보내기 상태
        var isExporting: Bool = false
        var exportProgress: Double = 0.0

        init(videoAsset: PHAsset) {
            self.videoAsset = videoAsset
        }
    }

    // MARK: - Edit State
    struct EditState: Equatable {
        var trimStartTime: Double = 0.0
        var trimEndTime: Double = 0.0
        var selectedFilter: FilterType? = nil
        // TODO: 추후 추가될 편집 옵션들
        // var subtitles: [Subtitle] = []
        // var audioAdjustments: AudioSettings?
    }

    enum FilterType: String, CaseIterable, Equatable {
        case blackAndWhite = "흑백"
        case warm = "따뜻한"
        case cool = "차갑게"
        case bright = "밝게"

        var displayName: String {
            return rawValue
        }

        /// CIFilter 이름 반환
        var ciFilterName: String? {
            switch self {
            case .blackAndWhite:
                return "CIPhotoEffectMono"
            case .warm:
                return nil // TODO: 추후 구현
            case .cool:
                return nil // TODO: 추후 구현
            case .bright:
                return nil // TODO: 추후 구현
            }
        }
    }

    enum SeekDirection: Equatable {
        case forward
        case backward
    }

    // MARK: - Action
    @CasePathable
    enum Action: Equatable {
        case playPauseButtonTapped
        case seekBackward
        case seekForward
        case seekCompleted
        case updateCurrentTime(Double)
        case updateDuration(Double)
        case updateTrimStartTime(Double)
        case updateTrimEndTime(Double)
        case filterSelected(FilterType)
        case filterApplied
        case nextButtonTapped
        case exportProgressUpdated(Double)
        case exportCompleted(URL)
        case exportFailed(String)
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .playPauseButtonTapped:
                state.isPlaying.toggle()
                return .none

            case .seekBackward:
                state.seekTrigger = .backward
                return .none

            case .seekForward:
                state.seekTrigger = .forward
                return .none

            case .seekCompleted:
                state.seekTrigger = nil
                return .none

            case .updateCurrentTime(let time):
                state.currentTime = time
                return .none

            case .updateDuration(let duration):
                state.duration = duration
                // duration이 설정되면 trim 범위를 전체로 초기화
                state.editState.trimStartTime = 0.0
                state.editState.trimEndTime = duration
                return .none

            case .updateTrimStartTime(let time):
                state.editState.trimStartTime = max(0, min(time, state.editState.trimEndTime - 0.1))
                return .none

            case .updateTrimEndTime(let time):
                state.editState.trimEndTime = min(state.duration, max(time, state.editState.trimStartTime + 0.1))
                return .none

            case .filterSelected(let filter):
                // 같은 필터를 다시 선택하면 선택 해제, 다른 필터를 선택하면 변경
                if state.editState.selectedFilter == filter {
                    state.editState.selectedFilter = nil
                    state.isApplyingFilter = true
                } else {
                    state.editState.selectedFilter = filter
                    state.isApplyingFilter = true
                }
                // 필터 적용 중에는 재생 중지
                state.isPlaying = false
                return .none

            case .filterApplied:
                state.isApplyingFilter = false
                return .none

            case .nextButtonTapped:
                state.isExporting = true
                state.exportProgress = 0.0

                return .run { [videoAsset = state.videoAsset, editState = state.editState] send in
                    do {
                        let exporter = VideoExporter()
                        let exportedURL = try await exporter.export(
                            asset: videoAsset,
                            editState: editState,
                            progressHandler: { progress in
                                Task {
                                    await send(.exportProgressUpdated(progress))
                                }
                            }
                        )
                        await send(.exportCompleted(exportedURL))
                    } catch {
                        await send(.exportFailed(error.localizedDescription))
                    }
                }

            case .exportProgressUpdated(let progress):
                state.exportProgress = progress
                return .none

            case .exportCompleted(let url):
                state.isExporting = false
                state.exportProgress = 1.0
                // TODO: 편집된 영상을 다음 화면(게시물 작성)으로 전달
                print("✅ 영상 내보내기 완료: \(url)")
                return .none

            case .exportFailed(let error):
                state.isExporting = false
                state.exportProgress = 0.0
                print("❌ 영상 내보내기 실패: \(error)")
                return .none
            }
        }
    }
}
