//
//  PostCreateFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/16/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct PostCreateFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var selectedCategory: FootballTeams = .all
        var hashtagInput: String = ""
        var hashtags: [String] = []
        var content: String = ""
        var selectedImageData: Data?
        var isUploading: Bool = false
        var errorMessage: String?
        var showSuccessAlert: Bool = false

        // 갤러리 피커
        @Presents var galleryPicker: GalleryPickerFeature.State?

        // 업로드 가능 여부
        var canUpload: Bool {
            // 이미지가 선택되고, 본문이 작성되어야 함
            return selectedImageData != nil &&
                   !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case categorySelected(FootballTeams)
        case hashtagInputChanged(String)
        case addHashtag
        case removeHashtag(String)
        case contentChanged(String)
        case selectImageTapped
        case removeImage
        case uploadButtonTapped
        case uploadResponse(Result<PostResponseDTO, Error>)
        case dismissSuccessAlert

        // 갤러리 피커
        case galleryPicker(PresentationAction<GalleryPickerFeature.Action>)

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case let (.categorySelected(lhsCategory), .categorySelected(rhsCategory)):
                return lhsCategory == rhsCategory
            case let (.hashtagInputChanged(lhsText), .hashtagInputChanged(rhsText)):
                return lhsText == rhsText
            case (.addHashtag, .addHashtag):
                return true
            case let (.removeHashtag(lhsTag), .removeHashtag(rhsTag)):
                return lhsTag == rhsTag
            case let (.contentChanged(lhsContent), .contentChanged(rhsContent)):
                return lhsContent == rhsContent
            case (.selectImageTapped, .selectImageTapped):
                return true
            case (.removeImage, .removeImage):
                return true
            case (.uploadButtonTapped, .uploadButtonTapped):
                return true
            case (.uploadResponse, .uploadResponse):
                return true
            case (.dismissSuccessAlert, .dismissSuccessAlert):
                return true
            case (.galleryPicker, .galleryPicker):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .categorySelected(category):
                state.selectedCategory = category
                return .none

            case let .hashtagInputChanged(text):
                // 띄어쓰기 제거
                state.hashtagInput = text.replacingOccurrences(of: " ", with: "")
                return .none

            case .addHashtag:
                let trimmed = state.hashtagInput.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmed.isEmpty else {
                    return .none
                }

                // # 제거 (사용자가 입력했을 수도 있으므로)
                let tag = trimmed.replacingOccurrences(of: "#", with: "")

                // 중복 체크
                guard !state.hashtags.contains(tag) else {
                    state.hashtagInput = ""
                    return .none
                }

                // 해시태그 추가
                state.hashtags.append(tag)
                state.hashtagInput = ""
                return .none

            case let .removeHashtag(tag):
                state.hashtags.removeAll { $0 == tag }
                return .none

            case let .contentChanged(content):
                state.content = content
                return .none

            case .selectImageTapped:
                // 갤러리 피커 열기 (게시물 모드)
                state.galleryPicker = GalleryPickerFeature.State(pickerMode: .post)
                return .none

            case .removeImage:
                // 선택된 이미지 제거
                state.selectedImageData = nil
                return .none

            case .uploadButtonTapped:
                // 유효성 검증
                guard state.selectedImageData != nil else {
                    state.errorMessage = "이미지를 선택해주세요"
                    return .none
                }

                guard !state.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    state.errorMessage = "내용을 입력해주세요"
                    return .none
                }

                state.isUploading = true
                state.errorMessage = nil

                print("게시글 업로드 시작")
                print("   카테고리: \(state.selectedCategory.rawValue)")
                print("   해시태그: \(state.hashtags)")
                print("   내용: \(state.content)")

                // 게시글 업로드
                return .run { [
                    imageData = state.selectedImageData!,
                    category = state.selectedCategory,
                    hashtags = state.hashtags,
                    content = state.content
                ] send in
                    do {
                        // content에 본문과 해시태그를 함께 포함
                        let hashtagString = hashtags.isEmpty ? "" : " " + hashtags.map { "#\($0)" }.joined(separator: " ")
                        let fullContent = content + hashtagString

                        // PostRequestDTO 생성
                        let postRequest = PostRequestDTO(
                            category: category.rawValue,
                            title: "게시글",
                            price: 0,
                            content: fullContent,
                            value1: "",
                            value2: "",
                            value3: "",
                            value4: "",
                            value5: "",
                            value6: "",
                            value7: "",
                            value8: "",
                            value9: "",
                            value10: "",
                            files: [],
                            longitude: GeoLocation.defaultLocation.longitude,
                            latitude: GeoLocation.defaultLocation.latitude
                        )

                        // PostService를 사용해서 게시글 생성 (이미지 업로드 포함)
                        let response = try await PostService.shared.createPost(
                            post: postRequest,
                            images: [imageData]
                        )

                        print("게시글 업로드 성공: \(response.postId)")
                        await send(.uploadResponse(.success(response)))
                    } catch {
                        print("게시글 업로드 실패: \(error)")
                        await send(.uploadResponse(.failure(error)))
                    }
                }

            case let .uploadResponse(.success(response)):
                state.isUploading = false
                print("게시글 업로드 성공: \(response.postId)")

                // 성공 후 상태 초기화
                state.selectedImageData = nil
                state.selectedCategory = .all
                state.hashtags = []
                state.content = ""
                state.hashtagInput = ""

                // 성공 알림 표시
                state.showSuccessAlert = true
                return .none

            case .dismissSuccessAlert:
                state.showSuccessAlert = false
                return .none

            case let .uploadResponse(.failure(error)):
                state.isUploading = false
                state.errorMessage = error.localizedDescription
                print("게시글 업로드 실패: \(error)")
                return .none

            case let .galleryPicker(.presented(.delegate(.didSelectImage(imageData)))):
                // 갤러리에서 이미지 선택 완료
                state.selectedImageData = imageData
                print("이미지 선택 완료: \(imageData.count) bytes")
                return .none

            case .galleryPicker:
                return .none
            }
        }
        .ifLet(\.$galleryPicker, action: \.galleryPicker) {
            GalleryPickerFeature()
        }
    }
}
