//
//  EditProfileFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/8/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct EditProfileFeature {

    // MARK: - State
    struct State: Equatable {
        var profile: Profile
        var nickname: String
        var introduce: String
        var profileImageData: Data?
        var isLoading: Bool = false

        @PresentationState var galleryPicker: GalleryPickerFeature.State?

        // Validation
        var isNicknameLengthValid: Bool {
            let trimmed = nickname.trimmingCharacters(in: .whitespaces)
            return trimmed.count >= 2 &&
                   trimmed.count <= 8 &&
                   !nickname.contains(" ")
        }

        var isNicknameCharacterValid: Bool {
            // 한글, 영문, 숫자만 허용
            let allowedCharacters = CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: "가-힣ㄱ-ㅎㅏ-ㅣ"))
            let nicknameCharacterSet = CharacterSet(charactersIn: nickname)
            return allowedCharacters.isSuperset(of: nicknameCharacterSet)
        }

        var isNicknameValid: Bool {
            return isNicknameLengthValid && isNicknameCharacterValid
        }

        var isIntroduceValid: Bool {
            introduce.count <= 20
        }

        var canSave: Bool {
            isNicknameValid && isIntroduceValid
        }

        init(profile: Profile, profileImageData: Data? = nil) {
            self.profile = profile
            self.nickname = profile.nickname
            self.introduce = profile.introduce ?? ""
            self.profileImageData = profileImageData
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case cancelButtonTapped
        case saveButtonTapped
        case profileImageTapped
        case nicknameChanged(String)
        case introduceChanged(String)
        case profileUpdated(Profile)
        case dismiss
        case galleryPicker(PresentationAction<GalleryPickerFeature.Action>)
        case profileImageCompressed(Data)
    }

    // MARK: - Body
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .cancelButtonTapped:
            return .run { send in
                await send(.dismiss)
            }

        case .saveButtonTapped:
            guard state.canSave else { return .none }
            state.isLoading = true

            return .run { [nickname = state.nickname,
                          introduce = state.introduce,
                          imageData = state.profileImageData] send in
                do {
                    // 프로필 이미지 MultipartFile 생성
                    let profileImageFile: MultipartFile? = imageData.map {
                        MultipartFile(
                            data: $0,
                            fileName: "profile.jpg",
                            mimeType: "image/jpeg"
                        )
                    }

                    // 프로필 업데이트 API 호출
                    let updatedProfile = try await NetworkManager.shared.performRequest(
                        ProfileRouter.updateMe(profile: .init(
                            nickname: nickname, profileImage: profileImageFile, introduce: introduce
                        )),
                        as: ProfileDTO.self
                    ).toDomain

                    await send(.profileUpdated(updatedProfile))
                } catch {
                    // TODO: 에러 처리
                    print("프로필 업데이트 실패: \(error)")
                }
            }

        case .profileImageTapped:
            state.galleryPicker = GalleryPickerFeature.State(
                pickerMode: .profileImage
            )
            return .none

        case .nicknameChanged(let nickname):
            state.nickname = nickname
            return .none

        case .introduceChanged(let introduce):
            state.introduce = introduce
            return .none

        case .profileUpdated:
            state.isLoading = false
            return .run { send in
                await send(.dismiss)
            }

        case .dismiss:
            return .run { _ in
                await self.dismiss()
            }

        case .galleryPicker(.presented(.delegate(.didSelectImage(let imageData)))):
            // 프로필 사진을 100KB 이하로 압축
            return .run { send in
                if let compressedData = await CompressHelper.compressImage(imageData, maxSizeInBytes: 100_000, maxWidth: 800, maxHeight: 800) {
                    await send(.profileImageCompressed(compressedData))
                }
            }

        case .profileImageCompressed(let data):
            state.profileImageData = data
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
