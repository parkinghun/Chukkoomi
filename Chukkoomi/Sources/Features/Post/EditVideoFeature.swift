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

        // 비디오 표시 크기 (자막 크기 계산용)
        var videoDisplaySize: CGSize = .zero

        // 내보내기 상태
        var isExporting: Bool = false
        var exportProgress: Double = 0.0

        // 자막 텍스트 입력 오버레이
        var isShowingSubtitleInput: Bool = false
        var subtitleInputText: String = ""
        var subtitleInputValidationError: String? = nil
        var pendingSubtitleStartTime: Double? = nil
        var pendingSubtitleEndTime: Double? = nil
        var editingSubtitleId: UUID? = nil  // 수정 중인 자막 ID

        // 음악 선택 오버레이
        var isShowingMusicSelection: Bool = false

        // Alert
        @Presents var alert: AlertState<Action.Alert>?

        init(videoAsset: PHAsset) {
            self.videoAsset = videoAsset
        }
    }

    // MARK: - Edit State
    struct EditState: Equatable {
        var trimStartTime: Double = 0.0
        var trimEndTime: Double = 0.0
        var selectedFilter: VideoFilter? = nil
        var subtitles: [Subtitle] = []
        var backgroundMusics: [BackgroundMusic] = []
    }

    // MARK: - Background Music
    struct BackgroundMusic: Equatable, Identifiable {
        let id: UUID
        var musicURL: URL
        var startTime: Double  // 비디오 기준 시작 시간
        var endTime: Double    // 비디오 기준 종료 시간
        var volume: Float      // 0.0 ~ 1.0

        init(id: UUID = UUID(), musicURL: URL, startTime: Double = 0.0, endTime: Double, volume: Float = 0.5) {
            self.id = id
            self.musicURL = musicURL
            self.startTime = startTime
            self.endTime = endTime
            self.volume = volume
        }
    }

    // MARK: - Subtitle
    struct Subtitle: Equatable, Identifiable {
        let id: UUID
        var startTime: Double
        var endTime: Double
        var text: String

        init(id: UUID = UUID(), startTime: Double, endTime: Double = 0.0, text: String = "") {
            self.id = id
            self.startTime = startTime
            self.endTime = endTime > 0 ? endTime : startTime + 5.0 // 기본 5초
            self.text = text
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
        case seekToTime(Double)
        case seekCompleted
        case updateCurrentTime(Double)
        case updateDuration(Double)
        case updateVideoDisplaySize(CGSize)
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
        case addSubtitle
        case editSubtitle(UUID)
        case removeSubtitle(UUID)
        case updateSubtitleStartTime(UUID, Double)
        case updateSubtitleEndTime(UUID, Double)
        case updateSubtitleInputText(String)
        case confirmSubtitleInput
        case cancelSubtitleInput

        // Background Music
        case showMusicSelection
        case cancelMusicSelection
        case selectMusic(URL)
        case removeBackgroundMusic(UUID)
        case updateBackgroundMusicStartTime(UUID, Double)
        case updateBackgroundMusicEndTime(UUID, Double)
        case updateBackgroundMusicVolume(UUID, Float)

        // Alert
        case alert(PresentationAction<Alert>)

        enum Alert: Equatable {
            case confirmSubtitleOverlapError
        }

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

            case .updateVideoDisplaySize(let size):
                state.videoDisplaySize = size
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

            case .preProcessFailed:
                state.isApplyingFilter = false
                state.editState.selectedFilter = nil  // 필터 선택 해제
                return .none

            case .completeButtonTapped:
                state.isExporting = true
                state.exportProgress = 0.0

                return .run { [videoAsset = state.videoAsset, editState = state.editState, preProcessedVideoURL = state.preProcessedVideoURL] send in
                    do {
                        let exporter = VideoExporter()
                        let exportedURL = try await exporter.export(
                            asset: videoAsset,
                            editState: editState,
                            preProcessedVideoURL: preProcessedVideoURL,
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

            case .addSubtitle:
                // 현재 playhead 위치에서 자막 추가
                let startTime = state.currentTime

                // 현재 위치가 기존 자막 블럭 안에 있는지 확인
                let isInsideExistingSubtitle = state.editState.subtitles.contains { subtitle in
                    startTime >= subtitle.startTime && startTime < subtitle.endTime
                }

                if isInsideExistingSubtitle {
                    state.alert = AlertState {
                        TextState("자막 추가 불가")
                    } actions: {
                        ButtonState(action: .confirmSubtitleOverlapError) {
                            TextState("확인")
                        }
                    } message: {
                        TextState("해당 위치에 이미 자막이 존재합니다.")
                    }
                    return .none
                }

                var endTime = min(startTime + 5.0, state.duration)

                // 겹치지 않는 영역 찾기
                let availableEndTime = findAvailableEndTime(
                    startTime: startTime,
                    desiredEndTime: endTime,
                    existingSubtitles: state.editState.subtitles
                )

                endTime = availableEndTime

                // 최소 0.5초 확보 안되면 에러
                if endTime - startTime < 0.5 {
                    state.alert = AlertState {
                        TextState("자막 추가 불가")
                    } actions: {
                        ButtonState(action: .confirmSubtitleOverlapError) {
                            TextState("확인")
                        }
                    } message: {
                        TextState("해당 위치에 자막을 추가할 공간이 부족합니다. (최소 0.5초 필요)")
                    }
                    return .none
                }

                // 텍스트 입력 오버레이 표시
                state.isShowingSubtitleInput = true
                state.subtitleInputText = ""
                state.subtitleInputValidationError = "자막 텍스트를 입력해주세요."
                state.pendingSubtitleStartTime = startTime
                state.pendingSubtitleEndTime = endTime
                return .none

            case .editSubtitle(let id):
                // 수정할 자막 찾기
                guard let subtitle = state.editState.subtitles.first(where: { $0.id == id }) else {
                    return .none
                }

                // 텍스트 입력 오버레이 표시 (기존 데이터로 초기화)
                state.isShowingSubtitleInput = true
                state.subtitleInputText = subtitle.text
                state.subtitleInputValidationError = nil  // 기존 텍스트는 유효함
                state.pendingSubtitleStartTime = subtitle.startTime
                state.pendingSubtitleEndTime = subtitle.endTime
                state.editingSubtitleId = id
                return .none

            case .updateSubtitleInputText(let text):
                state.subtitleInputText = text

                // 텍스트 검증
                let trimmedText = text.trimmingCharacters(in: .whitespaces)

                if trimmedText.isEmpty {
                    state.subtitleInputValidationError = "자막 텍스트를 입력해주세요."
                } else if trimmedText.count > 15 {
                    state.subtitleInputValidationError = "자막은 15자 이하로 입력해주세요."
                } else {
                    state.subtitleInputValidationError = nil
                }

                return .none

            case .confirmSubtitleInput:
                // 검증 에러가 있으면 무시
                guard state.subtitleInputValidationError == nil else {
                    return .none
                }

                // 입력한 텍스트로 자막 생성/수정
                guard let startTime = state.pendingSubtitleStartTime,
                      let endTime = state.pendingSubtitleEndTime else {
                    return .none
                }

                // 텍스트 검증
                let trimmedText = state.subtitleInputText.trimmingCharacters(in: .whitespaces)

                if let editingId = state.editingSubtitleId {
                    // 기존 자막 수정
                    if let index = state.editState.subtitles.firstIndex(where: { $0.id == editingId }) {
                        state.editState.subtitles[index].text = trimmedText
                        // 시작/종료 시간도 업데이트 (현재는 변경 안되지만 확장성 고려)
                        state.editState.subtitles[index].startTime = startTime
                        state.editState.subtitles[index].endTime = endTime
                    }
                } else {
                    // 새로운 자막 추가
                    let newSubtitle = Subtitle(
                        startTime: startTime,
                        endTime: endTime,
                        text: trimmedText
                    )
                    state.editState.subtitles.append(newSubtitle)
                    // 시작 시간 기준으로 정렬
                    state.editState.subtitles.sort { $0.startTime < $1.startTime }
                }

                // 오버레이 닫기
                state.isShowingSubtitleInput = false
                state.subtitleInputText = ""
                state.subtitleInputValidationError = nil
                state.pendingSubtitleStartTime = nil
                state.pendingSubtitleEndTime = nil
                state.editingSubtitleId = nil

                return .none

            case .cancelSubtitleInput:
                // 오버레이 닫기
                state.isShowingSubtitleInput = false
                state.subtitleInputText = ""
                state.subtitleInputValidationError = nil
                state.pendingSubtitleStartTime = nil
                state.pendingSubtitleEndTime = nil
                state.editingSubtitleId = nil
                return .none

            case .removeSubtitle(let id):
                // 자막 제거
                state.editState.subtitles.removeAll { $0.id == id }
                return .none

            case .updateSubtitleStartTime(let id, let time):
                // 자막 시작 시간 업데이트
                if let index = state.editState.subtitles.firstIndex(where: { $0.id == id }) {
                    let endTime = state.editState.subtitles[index].endTime
                    var clampedTime = max(0, min(time, endTime - 0.5)) // 최소 0.5초 길이 유지

                    // 왼쪽 인접 자막과 겹치지 않도록
                    let otherSubtitles = state.editState.subtitles.filter { $0.id != id }
                    for other in otherSubtitles {
                        // 왼쪽에 있는 자막과 겹침 방지
                        if other.endTime > clampedTime && other.startTime < clampedTime {
                            clampedTime = max(clampedTime, other.endTime)
                        }
                    }

                    // 최소 길이 확보 검증
                    if endTime - clampedTime >= 0.5 {
                        state.editState.subtitles[index].startTime = clampedTime
                    }
                }
                return .none

            case .updateSubtitleEndTime(let id, let time):
                // 자막 종료 시간 업데이트
                if let index = state.editState.subtitles.firstIndex(where: { $0.id == id }) {
                    let startTime = state.editState.subtitles[index].startTime
                    var clampedTime = min(state.duration, max(time, startTime + 0.5)) // 최소 0.5초 길이 유지

                    // 오른쪽 인접 자막과 겹치지 않도록
                    let otherSubtitles = state.editState.subtitles.filter { $0.id != id }
                    for other in otherSubtitles {
                        // 오른쪽에 있는 자막과 겹침 방지
                        if other.startTime < clampedTime && other.endTime > clampedTime {
                            clampedTime = min(clampedTime, other.startTime)
                        }
                    }

                    // 최소 길이 확보 검증
                    if clampedTime - startTime >= 0.5 {
                        state.editState.subtitles[index].endTime = clampedTime
                    }
                }
                return .none

            case .showMusicSelection:
                // 음악 선택 오버레이 표시
                state.isShowingMusicSelection = true
                return .none

            case .cancelMusicSelection:
                // 음악 선택 오버레이 닫기
                state.isShowingMusicSelection = false
                return .none

            case .selectMusic(let url):
                // 배경음악 추가 (현재 playhead 위치부터 시작)
                let startTime = state.currentTime

                // 현재 위치가 기존 배경음악 블럭 안에 있는지 확인
                let isInsideExistingMusic = state.editState.backgroundMusics.contains { music in
                    startTime >= music.startTime && startTime < music.endTime
                }

                if isInsideExistingMusic {
                    state.alert = AlertState {
                        TextState("배경음악 추가 불가")
                    } actions: {
                        ButtonState(action: .confirmSubtitleOverlapError) {
                            TextState("확인")
                        }
                    } message: {
                        TextState("해당 위치에 이미 배경음악이 존재합니다.")
                    }
                    state.isShowingMusicSelection = false
                    return .none
                }

                // 비디오 끝까지 (또는 다음 배경음악까지) 전체 영역 사용
                let desiredEndTime = state.duration

                // 겹치지 않는 영역 찾기
                let availableEndTime = findAvailableEndTimeForMusic(
                    startTime: startTime,
                    desiredEndTime: desiredEndTime,
                    existingMusics: state.editState.backgroundMusics
                )

                let endTime = availableEndTime

                // 최소 0.5초 확보 안되면 에러
                if endTime - startTime < 0.5 {
                    state.alert = AlertState {
                        TextState("배경음악 추가 불가")
                    } actions: {
                        ButtonState(action: .confirmSubtitleOverlapError) {
                            TextState("확인")
                        }
                    } message: {
                        TextState("해당 위치에 배경음악을 추가할 공간이 부족합니다. (최소 0.5초 필요)")
                    }
                    state.isShowingMusicSelection = false
                    return .none
                }

                let backgroundMusic = BackgroundMusic(
                    musicURL: url,
                    startTime: startTime,
                    endTime: endTime,
                    volume: 0.5
                )
                state.editState.backgroundMusics.append(backgroundMusic)
                // 시작 시간 기준으로 정렬
                state.editState.backgroundMusics.sort { $0.startTime < $1.startTime }
                state.isShowingMusicSelection = false
                return .none

            case .removeBackgroundMusic(let id):
                // 배경음악 제거
                state.editState.backgroundMusics.removeAll { $0.id == id }
                return .none

            case .updateBackgroundMusicStartTime(let id, let time):
                // 배경음악 시작 시간 업데이트
                if let index = state.editState.backgroundMusics.firstIndex(where: { $0.id == id }) {
                    let endTime = state.editState.backgroundMusics[index].endTime
                    var clampedTime = max(0, min(time, endTime - 0.5))

                    // 왼쪽 인접 배경음악과 겹치지 않도록
                    let otherMusics = state.editState.backgroundMusics.filter { $0.id != id }
                    for other in otherMusics {
                        // 왼쪽에 있는 음악과 겹침 방지
                        if other.endTime > clampedTime && other.startTime < clampedTime {
                            clampedTime = max(clampedTime, other.endTime)
                        }
                    }

                    // 최소 길이 확보 검증
                    if endTime - clampedTime >= 0.5 {
                        state.editState.backgroundMusics[index].startTime = clampedTime
                    }
                }
                return .none

            case .updateBackgroundMusicEndTime(let id, let time):
                // 배경음악 종료 시간 업데이트
                if let index = state.editState.backgroundMusics.firstIndex(where: { $0.id == id }) {
                    let startTime = state.editState.backgroundMusics[index].startTime
                    var clampedTime = min(state.duration, max(time, startTime + 0.5))

                    // 오른쪽 인접 배경음악과 겹치지 않도록
                    let otherMusics = state.editState.backgroundMusics.filter { $0.id != id }
                    for other in otherMusics {
                        // 오른쪽에 있는 음악과 겹침 방지
                        if other.startTime < clampedTime && other.endTime > clampedTime {
                            clampedTime = min(clampedTime, other.startTime)
                        }
                    }

                    // 최소 길이 확보 검증
                    if clampedTime - startTime >= 0.5 {
                        state.editState.backgroundMusics[index].endTime = clampedTime
                    }
                }
                return .none

            case .updateBackgroundMusicVolume(let id, let volume):
                // 배경음악 볼륨 업데이트
                if let index = state.editState.backgroundMusics.firstIndex(where: { $0.id == id }) {
                    state.editState.backgroundMusics[index].volume = max(0, min(1, volume))
                }
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Helper Functions
    private func findAvailableEndTime(
        startTime: Double,
        desiredEndTime: Double,
        existingSubtitles: [Subtitle]
    ) -> Double {
        // startTime 이후에 있는 자막들 중 가장 가까운 자막 찾기
        let nextSubtitles = existingSubtitles
            .filter { $0.startTime >= startTime }
            .sorted { $0.startTime < $1.startTime }

        if let nextSubtitle = nextSubtitles.first {
            // 다음 자막과 겹치지 않도록 endTime 조정
            return min(desiredEndTime, nextSubtitle.startTime)
        }

        return desiredEndTime
    }

    private func findAvailableEndTimeForMusic(
        startTime: Double,
        desiredEndTime: Double,
        existingMusics: [BackgroundMusic]
    ) -> Double {
        // startTime 이후에 있는 배경음악들 중 가장 가까운 음악 찾기
        let nextMusics = existingMusics
            .filter { $0.startTime >= startTime }
            .sorted { $0.startTime < $1.startTime }

        if let nextMusic = nextMusics.first {
            // 다음 배경음악과 겹치지 않도록 endTime 조정
            return min(desiredEndTime, nextMusic.startTime)
        }

        return desiredEndTime
    }
}

