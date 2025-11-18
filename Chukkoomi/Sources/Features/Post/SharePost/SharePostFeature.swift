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
        var availableUsers: [User] = []
        var selectedUserId: String? = nil // 단일 선택
        var isLoading: Bool = false

        @Presents var userSearch: UserSearchFeature.State?

        // 전송 가능 여부
        var canSend: Bool {
            selectedUserId != nil
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case searchBarTapped
        case userTapped(User)
        case sendTapped
        case closeButtonTapped

        // Network Responses
        case loadUsersResponse(Result<[User], Error>)
        case sendPostResponse(Result<Void, Error>)

        // User Search
        case userSearch(PresentationAction<UserSearchFeature.Action>)

        // Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            case dismiss
            case postShared
        }

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.searchBarTapped, .searchBarTapped),
                 (.sendTapped, .sendTapped),
                 (.closeButtonTapped, .closeButtonTapped):
                return true
            case let (.userTapped(lhs), .userTapped(rhs)):
                return lhs == rhs
            case (.loadUsersResponse, .loadUsersResponse),
                 (.sendPostResponse, .sendPostResponse):
                return true
            case let (.userSearch(lhs), .userSearch(rhs)):
                return lhs == rhs
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
                        // 1. 최근 채팅 유저 가져오기
                        let chatRoomResponse = try await NetworkManager.shared.performRequest(
                            ChatRouter.getChatRoomList,
                            as: ChatRoomListResponseDTO.self
                        )
                        let chatRooms = chatRoomResponse.data.map { $0.toDomain }

                        // 내 userId 가져오기
                        let myUserId = UserDefaultsHelper.userId ?? ""

                        // 최근 채팅 상대방 추출 (나를 제외한 참가자)
                        var recentChatUsers: [User] = []
                        for chatRoom in chatRooms {
                            if let otherUser = chatRoom.participants.first(where: { $0.userId != myUserId }) {
                                recentChatUsers.append(User(
                                    userId: otherUser.userId,
                                    nickname: otherUser.nick,
                                    profileImage: otherUser.profileImage
                                ))
                            }
                        }

                        // 2. 팔로우 유저 가져오기
                        let profileResponse = try await NetworkManager.shared.performRequest(
                            ProfileRouter.lookupMe,
                            as: ProfileDTO.self
                        )
                        let followingUsers = profileResponse.following.map { $0.toDomain }

                        // 3. 합쳐서 중복 제거 후 최대 8명
                        var uniqueUsers: [User] = []
                        var seenIds = Set<String>()

                        // 최근 채팅 우선
                        for user in recentChatUsers where !seenIds.contains(user.userId) {
                            uniqueUsers.append(user)
                            seenIds.insert(user.userId)
                            if uniqueUsers.count >= 8 { break }
                        }

                        // 팔로우 유저 추가
                        for user in followingUsers where !seenIds.contains(user.userId) {
                            uniqueUsers.append(user)
                            seenIds.insert(user.userId)
                            if uniqueUsers.count >= 8 { break }
                        }

                        print("📤 공유 가능한 사용자 목록: \(uniqueUsers.count)명")
                        print("   - 최근 채팅: \(recentChatUsers.count)명")
                        print("   - 팔로우: \(followingUsers.count)명")

                        await send(.loadUsersResponse(.success(uniqueUsers)))
                    } catch {
                        print("❌ 사용자 목록 로드 실패: \(error)")
                        await send(.loadUsersResponse(.failure(error)))
                    }
                }

            case let .userTapped(user):
                // 단일 사용자 선택/해제 토글
                if state.selectedUserId == user.userId {
                    state.selectedUserId = nil
                } else {
                    state.selectedUserId = user.userId
                }
                return .none

            case .sendTapped:
                // 선택된 사용자에게 게시글 공유
                guard let selectedUserId = state.selectedUserId else { return .none }

                return .run { [postId = state.post.id] send in
                    do {
                        // TODO: 실제 공유 API 호출
                        print("게시글 공유: \(postId) to \(selectedUserId)")

                        // 임시로 성공 처리
                        try await Task.sleep(for: .milliseconds(500))
                        await send(.sendPostResponse(.success(())))
                    } catch {
                        await send(.sendPostResponse(.failure(error)))
                    }
                }

            case .searchBarTapped:
                // 검색 화면 표시 (delegate 모드)
                state.userSearch = UserSearchFeature.State(useDelegate: true)
                return .none

            case .closeButtonTapped:
                return .send(.delegate(.dismiss))

            case let .userSearch(.presented(.delegate(.userSelected(user)))):
                // 검색에서 유저 선택됨
                print("✅ 유저 선택됨: \(user.nickname)")

                // 이미 목록에 있는지 확인
                if let existingIndex = state.availableUsers.firstIndex(where: { $0.userId == user.userId }) {
                    // 기존 유저를 맨 앞으로 이동
                    let existingUser = state.availableUsers.remove(at: existingIndex)
                    state.availableUsers.insert(existingUser, at: 0)
                    print("   기존 유저를 맨 앞으로 이동")
                } else {
                    // 새 유저를 맨 앞에 추가 (최대 8명 유지)
                    state.availableUsers.insert(user, at: 0)
                    if state.availableUsers.count > 8 {
                        state.availableUsers.removeLast()
                    }
                    print("   새 유저 추가")
                }

                // 해당 유저를 선택 상태로
                state.selectedUserId = user.userId

                // 검색 화면 닫기
                state.userSearch = nil
                return .none

            case .userSearch(.presented(.delegate(.dismiss))):
                // 검색 화면 닫기
                state.userSearch = nil
                return .none

            case .userSearch:
                return .none

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
        .ifLet(\.$userSearch, action: \.userSearch) {
            UserSearchFeature()
        }
    }
}
