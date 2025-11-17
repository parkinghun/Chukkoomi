//
//  UserSearchFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/10/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct UserSearchFeature {

    // MARK: - State
    struct State: Equatable {
        var searchText: String = ""
        var searchResults: [SearchResult] = []
        var isLoading: Bool = false
        var isSearching: Bool = false
        var excludeMyself: Bool = true  // 기본값: 자신 제외 (프로필용)

        @PresentationState var otherProfile: OtherProfileFeature.State?
    }

    // MARK: - Action
    enum Action: Equatable {
        case searchTextChanged(String)
        case search
        case userTapped(String) // userId
        case searchResultsLoaded([SearchResult])
        case clearSearch

        // Navigation
        case otherProfile(PresentationAction<OtherProfileFeature.Action>)
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .searchTextChanged(let text):
                state.searchText = text
                // 검색어가 비어있으면 결과 초기화
                if text.isEmpty {
                    state.searchResults = []
                    state.isSearching = false
                }
                return .none

            case .search:
                guard !state.searchText.isEmpty else {
                    return .none
                }

                state.isLoading = true
                state.isSearching = true

                return .run { [searchText = state.searchText, excludeMyself = state.excludeMyself] send in
                    do {
                        let myId = UserDefaultsHelper.userId

                        // 닉네임으로 유저 검색 API 호출
                        var users = try await NetworkManager.shared.performRequest(
                            UserRouter.search(nickname: searchText),
                            as: UserListDTO.self
                        ).toDomain

                        // excludeMyself가 true면 자신을 제외
                        if excludeMyself, let myId = myId {
                            users = users.filter { $0.userId != myId }
                        }

                        // User를 SearchResult로 변환
                        let searchResults = users.map { user in
                            SearchResult(user: user)
                        }

                        await send(.searchResultsLoaded(searchResults))
                    } catch {
                        // TODO: 에러 처리
                        print("유저 검색 실패: \(error)")
                        await send(.searchResultsLoaded([]))
                    }
                }

            case .userTapped(let userId):
                state.otherProfile = OtherProfileFeature.State(userId: userId)
                return .none

            case .searchResultsLoaded(let results):
                state.searchResults = results
                state.isLoading = false
                return .none

            case .clearSearch:
                state.searchText = ""
                state.searchResults = []
                state.isSearching = false
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
extension UserSearchFeature {
    struct SearchResult: Equatable, Identifiable {
        let user: User

        var id: String {
            user.userId
        }
    }
}
