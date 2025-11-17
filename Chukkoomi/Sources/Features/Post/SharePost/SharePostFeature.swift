//
//  SharePostFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/18/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SharePostFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        let post: Post
        var searchText: String = ""
        var availableUsers: [User] = []
        var selectedUsers: Set<String> = []
        var isLoading: Bool = false

        // 검색 필터링된 사용자 목록
        var filteredUsers: [User] {
            if searchText.isEmpty {
                return availableUsers
            }
            return availableUsers.filter { user in
                user.nickname.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 전송 가능 여부
        var canSend: Bool {
            !selectedUsers.isEmpty
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case searchTextChanged(String)
        case searchSubmitted
        case searchCleared
        case userTapped(User)
        case sendTapped
        case closeButtonTapped

        // Network Responses
        case loadUsersResponse(Result<[User], Error>)
        case sendPostResponse(Result<Void, Error>)

        // Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            case dismiss
            case postShared
        }

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.searchSubmitted, .searchSubmitted),
                 (.searchCleared, .searchCleared),
                 (.sendTapped, .sendTapped),
                 (.closeButtonTapped, .closeButtonTapped):
                return true
            case let (.searchTextChanged(lhs), .searchTextChanged(rhs)):
                return lhs == rhs
            case let (.userTapped(lhs), .userTapped(rhs)):
                return lhs == rhs
            case (.loadUsersResponse, .loadUsersResponse),
                 (.sendPostResponse, .sendPostResponse):
                return true
            case let (.delegate(lhs), .delegate(rhs)):
                return lhs == rhs
            default:
                return false
            }
        }
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 사용자 목록 로드
                state.isLoading = true
                return .run { send in
                    do {
                        // TODO: 실제 API 호출로 대체
                        // 1. 최근 채팅 유저 가져오기
                        // 2. 팔로우 유저 가져오기
                        // 3. 합쳐서 중복 제거 후 최대 8명

                        // 임시 더미 데이터
                        let dummyUsers = [
                            User(userId: "1", nickname: "냥이", profileImage: nil),
                            User(userId: "2", nickname: "아나", profileImage: nil),
                            User(userId: "3", nickname: "아나나", profileImage: nil),
                            User(userId: "4", nickname: "아나나나", profileImage: nil),
                            User(userId: "5", nickname: "멍이", profileImage: nil),
                            User(userId: "6", nickname: "토끼", profileImage: nil),
                            User(userId: "7", nickname: "호랑이", profileImage: nil),
                            User(userId: "8", nickname: "사자", profileImage: nil),
                        ]

                        await send(.loadUsersResponse(.success(dummyUsers)))
                    } catch {
                        await send(.loadUsersResponse(.failure(error)))
                    }
                }

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case .searchSubmitted:
                // 검색 실행 (현재는 자동으로 필터링되므로 별도 작업 불필요)
                return .none

            case .searchCleared:
                // 검색어 초기화
                state.searchText = ""
                return .none

            case let .userTapped(user):
                // 사용자 선택/해제 토글
                if state.selectedUsers.contains(user.userId) {
                    state.selectedUsers.remove(user.userId)
                } else {
                    state.selectedUsers.insert(user.userId)
                }
                return .none

            case .sendTapped:
                // 선택된 사용자들에게 게시글 공유
                guard !state.selectedUsers.isEmpty else { return .none }

                return .run { [postId = state.post.id, selectedUsers = state.selectedUsers] send in
                    do {
                        // TODO: 실제 공유 API 호출
                        print("게시글 공유: \(postId) to \(selectedUsers)")

                        // 임시로 성공 처리
                        try await Task.sleep(for: .milliseconds(500))
                        await send(.sendPostResponse(.success(())))
                    } catch {
                        await send(.sendPostResponse(.failure(error)))
                    }
                }

            case .closeButtonTapped:
                return .send(.delegate(.dismiss))

            case let .loadUsersResponse(.success(users)):
                state.isLoading = false
                state.availableUsers = users
                return .none

            case let .loadUsersResponse(.failure(error)):
                state.isLoading = false
                print("사용자 목록 로드 실패: \(error)")
                return .none

            case .sendPostResponse(.success):
                print("게시글 공유 성공")
                return .send(.delegate(.postShared))

            case let .sendPostResponse(.failure(error)):
                print("게시글 공유 실패: \(error)")
                // TODO: 에러 토스트 표시
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
