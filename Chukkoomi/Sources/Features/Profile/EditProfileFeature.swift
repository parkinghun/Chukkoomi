//
//  EditProfileFeature.swift
//  Chukkoomi
//
//  Created by Claude on 11/8/25.
//

import ComposableArchitecture
import Foundation

struct EditProfileFeature: Reducer {

    // MARK: - State
    struct State: Equatable {
        var profile: Profile
        var nickname: String
        var introduce: String
        var profileImageData: Data?
        var isLoading: Bool = false

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
    }

    // MARK: - Reducer
    @Dependency(\.dismiss) var dismiss

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
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
            // TODO: 커스텀 갤러리 화면으로 이동
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
        }
    }
}
