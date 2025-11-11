//
//  FollowListFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/11/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct FollowListFeature {

    // MARK: - State
    struct State: Equatable {
        var listType: ListType
        var users: [UserItem] = []
        var searchText: String = ""
        var isLoading: Bool = false

        @PresentationState var otherProfile: OtherProfileFeature.State?

        var title: String {
            switch listType {
            case .followers:
                return "팔로워"
            case .following:
                return "팔로잉"
            }
        }

        var filteredUsers: [UserItem] {
            if searchText.isEmpty {
                return users
            } else {
                return users.filter { $0.user.nickname.localizedCaseInsensitiveContains(searchText) }
            }
        }

        enum ListType: Equatable {
            case followers(userId: String)
            case following(userId: String)
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case userTapped(String)
        case usersLoaded([User])
        case profileImageLoaded(userId: String, data: Data)
        case searchTextChanged(String)
        case clearSearch
        case otherProfile(PresentationAction<OtherProfileFeature.Action>)
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [listType = state.listType] send in
                    do {
                        let profile: Profile
                        switch listType {
                        case .followers(let userId), .following(let userId):
                            // userId가 "me"이면 내 프로필, 아니면 다른 사람 프로필 조회
                            if userId == "me" {
                                profile = try await NetworkManager.shared.performRequest(
                                    ProfileRouter.lookupMe,
                                    as: ProfileDTO.self
                                ).toDomain
                            } else {
                                profile = try await NetworkManager.shared.performRequest(
                                    ProfileRouter.lookupOther(id: userId),
                                    as: ProfileDTO.self
                                ).toDomain
                            }
                        }

                        // 팔로워 또는 팔로잉 목록 추출
                        let users: [User]
                        switch listType {
                        case .followers:
                            users = profile.followers
                        case .following:
                            users = profile.following
                        }

                        await send(.usersLoaded(users))
                    } catch {
                        print("팔로우 목록 로드 실패: \(error)")
                    }
                }

            case .userTapped(let userId):
                state.otherProfile = OtherProfileFeature.State(userId: userId)
                return .none

            case .usersLoaded(let users):
                state.users = users.map { user in
                    UserItem(user: user, profileImageData: nil)
                }
                state.isLoading = false

                // 각 유저의 프로필 이미지 다운로드
                let effects = users.compactMap { user -> Effect<Action>? in
                    guard let imagePath = user.profileImage else { return nil }
                    return .run { send in
                        do {
                            let imageData = try await NetworkManager.shared.download(
                                MediaRouter.getData(path: imagePath)
                            )
                            await send(.profileImageLoaded(userId: user.userId, data: imageData))
                        } catch {
                            print("프로필 이미지 로드 실패: \(error)")
                        }
                    }
                }
                return .merge(effects)

            case .profileImageLoaded(let userId, let data):
                if let index = state.users.firstIndex(where: { $0.user.userId == userId }) {
                    state.users[index].profileImageData = data
                }
                return .none

            case .searchTextChanged(let text):
                state.searchText = text
                return .none

            case .clearSearch:
                state.searchText = ""
                return .none

            case .otherProfile:
                return .none
            }
        }
        .ifLet(\.$otherProfile, action: \.otherProfile) {
            OtherProfileFeature()
        }
    }
}

// MARK: - Models
extension FollowListFeature {
    struct UserItem: Equatable, Identifiable {
        var id: String { user.userId }
        let user: User
        var profileImageData: Data?
    }
}
