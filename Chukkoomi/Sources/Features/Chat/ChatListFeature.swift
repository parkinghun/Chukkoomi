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
        }
    }
}
