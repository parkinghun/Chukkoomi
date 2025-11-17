//
//  ChatListFeature.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/11/25.
//

import ComposableArchitecture
import Foundation

struct ChatListFeature: Reducer {

    // MARK: - State
    struct State: Equatable {
        var chatRooms: [ChatRoom] = []
        var isLoading: Bool = false
        var myUserId: String?
        @PresentationState var chat: ChatFeature.State?
        @PresentationState var userSearch: UserSearchFeature.State?
    }

    // MARK: - Action
    @CasePathable
    enum Action: Equatable {
        case onAppear
        case loadMyProfile
        case myProfileLoaded(String)
        case loadChatRooms
        case chatRoomsLoaded([ChatRoom])
        case chatRoomTapped(ChatRoom)
        case userSearchButtonTapped
        case chat(PresentationAction<ChatFeature.Action>)
        case userSearch(PresentationAction<UserSearchFeature.Action>)
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 채팅 화면이 열려있으면 onAppear 무시 (중복 호출 방지)
                if state.chat != nil {
                    return .none
                }

                state.isLoading = true

                // myUserId는 한 번만 로드, chatRooms는 항상 새로고침
                if state.myUserId == nil {
                    // myUserId 먼저 로드 (순차 실행)
                    return .send(.loadMyProfile)
                } else {
                    return .send(.loadChatRooms)
                }

            case .loadMyProfile:
                return .run { send in
                    do {
                        let profile = try await NetworkManager.shared.performRequest(
                            ProfileRouter.lookupMe,
                            as: ProfileDTO.self
                        ).toDomain
                        await send(.myProfileLoaded(profile.userId))
                    } catch {
                        // TODO: 에러 처리
                    }
                }

            case .myProfileLoaded(let userId):
                state.myUserId = userId
                // myUserId 로드 완료 후 chatRooms 로드
                return .send(.loadChatRooms)

            case .loadChatRooms:
                return .run { send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            ChatRouter.getChatRoomList,
                            as: ChatRoomListResponseDTO.self
                        )
                        let chatRooms = response.data.map { $0.toDomain }
                        await send(.chatRoomsLoaded(chatRooms))
                    } catch {
                        // TODO: 에러 처리
                        await send(.chatRoomsLoaded([]))
                    }
                }

            case .chatRoomsLoaded(let chatRooms):
                state.chatRooms = chatRooms
                state.isLoading = false
                return .none

            case .chatRoomTapped(let chatRoom):
                // 이미 채팅 화면이 열려있으면 무시 (중복 push 방지)
                guard state.chat == nil else {
                    return .none
                }

                // myUserId가 로드되지 않았으면 기다림
                guard let myUserId = state.myUserId else {
                    return .none
                }

                // 상대방 정보 추출
                let opponent: ChatUser
                if let opponentUser = chatRoom.participants.first(where: { $0.userId != myUserId }) {
                    opponent = opponentUser
                } else {
                    // 나 자신과의 채팅방이거나 상대방을 찾을 수 없는 경우 첫 번째 participant 사용
                    opponent = chatRoom.participants.first ?? ChatUser(userId: "", nick: "Unknown", profileImage: nil)
                }

                state.chat = ChatFeature.State(chatRoom: chatRoom, opponent: opponent, myUserId: myUserId)
                return .none

            case .chat(.dismiss):
                state.chat = nil
                // 채팅방 리스트 새로고침하여 최신 메시지 시간 업데이트
                return .send(.loadChatRooms)

            case .chat:
                return .none

            case .userSearchButtonTapped:
                state.userSearch = UserSearchFeature.State(excludeMyself: false)
                return .none

            case .userSearch:
                return .none
            }
        }
        .ifLet(\.$chat, action: \.chat) {
            ChatFeature()
        }
        .ifLet(\.$userSearch, action: \.userSearch) {
            UserSearchFeature()
        }
    }
}
