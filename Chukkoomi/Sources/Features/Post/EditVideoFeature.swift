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
        var seekTarget: Double? = nil

        // 편집 데이터
        var editState: EditState = EditState()

        // 필터 적용 상태
        var isApplyingFilter: Bool = false

        // AnimeGAN 전처리된 비디오 (무거운 필터는 미리 처리)
        var preProcessedVideoURL: URL? = nil

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
        var selectedFilter: VideoFilter? = nil
        // TODO: 추후 추가될 편집 옵션들
        // var subtitles: [Subtitle] = []
        // var audioAdjustments: AudioSettings?
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
        case seekToTime(Double)
        case seekCompleted
        case updateCurrentTime(Double)
        case updateDuration(Double)
        case updateTrimStartTime(Double)
        case updateTrimEndTime(Double)
        case filterSelected(VideoFilter)
        case filterApplied
        case preProcessCompleted(URL)
        case preProcessFailed(String)
        case completeButtonTapped
        case exportProgressUpdated(Double)
        case exportCompleted(URL)
        case exportFailed(String)
        case playbackEnded

        // Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            case videoExportCompleted(URL)
        }
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

            case .seekToTime(let time):
                state.seekTarget = time
                return .none

            case .seekCompleted:
                state.seekTrigger = nil
                state.seekTarget = nil
                return .none

            case .updateCurrentTime(let time):
                // duration을 넘지 않도록 클램프
                let clamped = min(time, state.duration)
                state.currentTime = clamped
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
                // 필터 적용 중에는 재생 중지
                state.isPlaying = false

                // 같은 필터를 다시 선택하면 선택 해제
                if state.editState.selectedFilter == filter {
                    state.editState.selectedFilter = nil
                    state.preProcessedVideoURL = nil  // 전처리된 비디오 제거
                    // 필터 해제는 즉시 완료 (로딩 필요 없음)
                    return .none
                }

                // 다른 필터 선택
                state.editState.selectedFilter = filter

                // AnimeGAN 필터는 미리 전처리 필요 (실시간 재생이 너무 느림)
                if filter == .animeGANHayao {
                    state.isApplyingFilter = true
                    return .run { [videoAsset = state.videoAsset, duration = state.duration] send in
                        do {
                            // AnimeGAN 필터를 미리 적용한 비디오 생성
                            let exporter = VideoExporter()
                            let tempEditState = EditState(
                                trimStartTime: 0.0,
                                trimEndTime: duration > 0 ? duration : .infinity,  // 전체 영상
                                selectedFilter: .animeGANHayao
                            )
                            let processedURL = try await exporter.export(
                                asset: videoAsset,
                                editState: tempEditState,
                                progressHandler: { _ in }
                            )
                            await send(.preProcessCompleted(processedURL))
                        } catch {
                            await send(.preProcessFailed(error.localizedDescription))
                        }
                    }
                } else {
                    // 다른 필터는 실시간 적용 가능
                    state.preProcessedVideoURL = nil
                    // 실시간 필터는 즉시 적용되므로 로딩 없음
                    return .none
                }

            case .filterApplied:
                state.isApplyingFilter = false
                return .none

            case .preProcessCompleted(let url):
                state.preProcessedVideoURL = url
                state.isApplyingFilter = false
                return .none

            case .preProcessFailed(let error):
                state.isApplyingFilter = false
                state.editState.selectedFilter = nil  // 필터 선택 해제
                print("❌ 필터 전처리 실패: \(error)")
                return .none

            case .completeButtonTapped:
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
                print("✅ 영상 내보내기 완료: \(url)")
                // 편집된 영상을 PostCreateFeature로 전달
                return .send(.delegate(.videoExportCompleted(url)))

            case .exportFailed(let error):
                state.isExporting = false
                state.exportProgress = 0.0
                print("❌ 영상 내보내기 실패: \(error)")
                return .none

            case .playbackEnded:
                // 재생이 종료되면 재생 상태를 끄고, 시간을 끝으로 고정
                state.isPlaying = false
                state.currentTime = state.duration
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

