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
                state.isLoading = true
                return .run { send in
                    do {
                        let chatRoomResponse = try await NetworkManager.shared.performRequest(
                            ChatRouter.getChatRoomList,
                            as: ChatRoomListResponseDTO.self
                        )
                        let chatRooms = chatRoomResponse.data.map { $0.toDomain }

                        let myUserId = UserDefaultsHelper.userId ?? ""

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

                        let profileResponse = try await NetworkManager.shared.performRequest(
                            ProfileRouter.lookupMe,
                            as: ProfileDTO.self
                        )
                        let followingUsers = profileResponse.following.map { $0.toDomain }

                        var uniqueUsers: [User] = []
                        var seenIds = Set<String>()

                        for user in recentChatUsers where !seenIds.contains(user.userId) {
                            uniqueUsers.append(user)
                            seenIds.insert(user.userId)
                            if uniqueUsers.count >= 8 { break }
                        }

                        for user in followingUsers where !seenIds.contains(user.userId) {
                            uniqueUsers.append(user)
                            seenIds.insert(user.userId)
                            if uniqueUsers.count >= 8 { break }
                        }

                        await send(.loadUsersResponse(.success(uniqueUsers)))
                    } catch {
                        await send(.loadUsersResponse(.failure(error)))
                    }
                }

            case let .userTapped(user):
                if state.selectedUserId == user.userId {
                    state.selectedUserId = nil
                } else {
                    state.selectedUserId = user.userId
                }
                return .none

            case .sendTapped:
                guard let selectedUserId = state.selectedUserId else { return .none }

                return .run { [post = state.post, availableUsers = state.availableUsers] send in
                    do {
                        guard availableUsers.contains(where: { $0.userId == selectedUserId }) else {
                            throw NSError(domain: "SharePost", code: -1, userInfo: [NSLocalizedDescriptionKey: "사용자를 찾을 수 없습니다"])
                        }

                        let chatRoomResponse = try await NetworkManager.shared.performRequest(
                            ChatRouter.getChatRoomList,
                            as: ChatRoomListResponseDTO.self
                        )
                        let chatRooms = chatRoomResponse.data.map { $0.toDomain }

                        let myUserId = UserDefaultsHelper.userId ?? ""

                        let existingRoom = chatRooms.first { room in
                            let hasSelectedUser = room.participants.contains(where: { $0.userId == selectedUserId })
                            let hasMyUser = room.participants.contains(where: { $0.userId == myUserId })
                            return hasSelectedUser && hasMyUser
                        }

                        var roomId: String

                        if let existing = existingRoom {
                            roomId = existing.roomId
                        } else {
                            roomId = selectedUserId
                        }

                        let filesString = post.files.joined(separator: ",")
                        let contentPreview = String(post.content.prefix(100))
                        let creatorNick = post.creator?.nickname ?? ""
                        let creatorProfileImage = post.creator?.profileImage ?? ""
                        let shareMessage = "[SHARED_POST]postId:\(post.id)|content:\(contentPreview)|files:\(filesString)|creatorNick:\(creatorNick)|creatorProfileImage:\(creatorProfileImage)"

                        _ = try await NetworkManager.shared.performRequest(
                            ChatRouter.sendMessage(roomId: roomId, content: shareMessage, files: nil),
                            as: ChatMessageResponseDTO.self
                        )

                        await send(.sendPostResponse(.success(())))
                    } catch {
                        await send(.sendPostResponse(.failure(error)))
                    }
                }

            case .searchBarTapped:
                state.userSearch = UserSearchFeature.State(useDelegate: true)
                return .none

            case .closeButtonTapped:
                return .send(.delegate(.dismiss))

            case let .userSearch(.presented(.delegate(.userSelected(user)))):
                if let existingIndex = state.availableUsers.firstIndex(where: { $0.userId == user.userId }) {
                    let existingUser = state.availableUsers.remove(at: existingIndex)
                    state.availableUsers.insert(existingUser, at: 0)
                } else {
                    state.availableUsers.insert(user, at: 0)
                    if state.availableUsers.count > 8 {
                        state.availableUsers.removeLast()
                    }
                }

                state.selectedUserId = user.userId
                state.userSearch = nil
                return .none

            case .userSearch(.presented(.delegate(.dismiss))):
                state.userSearch = nil
                return .none

            case .userSearch:
                return .none

            case let .loadUsersResponse(.success(users)):
                state.isLoading = false
                state.availableUsers = users
                return .none

            case .loadUsersResponse(.failure):
                state.isLoading = false
                return .none

            case .sendPostResponse(.success):
                return .send(.delegate(.postShared))

            case .sendPostResponse(.failure):
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
