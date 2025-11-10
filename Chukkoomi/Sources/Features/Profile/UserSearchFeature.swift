//
//  UserSearchFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/10/25.
//

import ComposableArchitecture
import Foundation

struct UserSearchFeature: Reducer {

    // MARK: - State
    struct State: Equatable {
        var searchText: String = ""
        var searchResults: [SearchResult] = []
        var isLoading: Bool = false
        var isSearching: Bool = false
    }

    // MARK: - Action
    enum Action: Equatable {
        case searchTextChanged(String)
        case search
        case userTapped(String) // userId
        case searchResultsLoaded([SearchResult])
        case profileImageDownloaded(userId: String, data: Data)
        case clearSearch
    }

    // MARK: - Reducer
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
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

            return .run { [searchText = state.searchText] send in
                do {
                    // 닉네임으로 유저 검색 API 호출
                    let users = try await NetworkManager.shared.performRequest(
                        UserRouter.search(nickname: searchText),
                        as: UserListDTO.self
                    ).toDomain

                    // User를 SearchResult로 변환
                    let searchResults = users.map { user in
                        SearchResult(
                            user: user,
                            profileImageData: nil
                        )
                    }

                    await send(.searchResultsLoaded(searchResults))
                } catch {
                    // TODO: 에러 처리
                    print("유저 검색 실패: \(error)")
                    await send(.searchResultsLoaded([]))
                }
            }

        case .userTapped(let userId):
            // TODO: 해당 유저 프로필 화면으로 이동
            return .none

        case .searchResultsLoaded(let results):
            state.searchResults = results
            state.isLoading = false

            // 프로필 이미지 다운로드
            let downloadEffects = results.compactMap { result -> Effect<Action>? in
                guard let imagePath = result.user.profileImage else { return nil }
                return .run { send in
                    do {
                        let imageData = try await NetworkManager.shared.download(
                            MediaRouter.getData(path: imagePath)
                        )
                        await send(.profileImageDownloaded(userId: result.user.userId, data: imageData))
                    } catch {
                        print("프로필 이미지 다운로드 실패: \(error)")
                    }
                }
            }

            return .merge(downloadEffects)

        case .profileImageDownloaded(let userId, let data):
            if let index = state.searchResults.firstIndex(where: { $0.user.userId == userId }) {
                state.searchResults[index].profileImageData = data
            }
            return .none

        case .clearSearch:
            state.searchText = ""
            state.searchResults = []
            state.isSearching = false
            return .none
        }
    }
}

// MARK: - Models
extension UserSearchFeature {
    struct SearchResult: Equatable, Identifiable {
        let user: User
        var profileImageData: Data?

        var id: String {
            user.userId
        }
    }
}
