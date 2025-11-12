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
<<<<<<< HEAD
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
                guard state.myUserId != nil else {
                    return .none
                }

                state.chat = ChatFeature.State(chatRoom: chatRoom, myUserId: state.myUserId)
                return .none

            case .chat(.dismiss):
                state.chat = nil
                // 채팅방 리스트 새로고침하여 최신 메시지 시간 업데이트
                return .send(.loadChatRooms)

            case .chat:
                return .none

            case .userSearchButtonTapped:
                state.userSearch = UserSearchFeature.State()
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
=======
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case loadChatRooms
        case chatRoomsLoaded([ChatRoom])
        case chatRoomTapped(ChatRoom)
    }

    // MARK: - Reducer
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isLoading = true
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
                    print("채팅방 리스트 로드 실패: \(error)")
                    await send(.chatRoomsLoaded([]))
                }
            }

        case .chatRoomsLoaded(let chatRooms):
            state.chatRooms = chatRooms
            state.isLoading = false
            return .none

        case .chatRoomTapped(let chatRoom):
            // TODO: 채팅방으로 이동
            print("채팅방 선택: \(chatRoom.roomId)")
            return .none
>>>>>>> 34c0a81 (feat: 채팅 리스트 화면 구현 및 탭바 연결)
        }
    }
}
