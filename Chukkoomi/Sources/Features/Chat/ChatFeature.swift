//
//  ChatFeature.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/12/25.
//

import ComposableArchitecture
import Foundation

struct ChatFeature: Reducer {

    // MARK: - State
    struct State: Equatable {
        let chatRoom: ChatRoom
        let myUserId: String?
        var messages: [ChatMessage] = []
        var messageText: String = ""
        var isLoading: Bool = false
        var isSending: Bool = false
        var cursorDate: String?
        var hasMoreMessages: Bool = true
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case loadMessages
        case messagesLoaded([ChatMessage], hasMore: Bool)
        case messageTextChanged(String)
        case sendMessageTapped
        case messageSent(ChatMessage)
        case loadMoreMessages
        case messageLoadFailed(String)
        case messageSendFailed(String)
    }

    // MARK: - Reducer
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isLoading = true
            return .send(.loadMessages)

        case .loadMessages:
            return .run { [roomId = state.chatRoom.roomId, cursorDate = state.cursorDate] send in
                do {
                    let response = try await NetworkManager.shared.performRequest(
                        ChatRouter.getChatHistory(roomId: roomId, cursorDate: cursorDate),
                        as: ChatMessageListResponseDTO.self
                    )
                    let messages = response.data.map { $0.toDomain }
                    let hasMore = messages.count >= 20 // API가 20개씩 반환한다고 가정
                    await send(.messagesLoaded(messages, hasMore: hasMore))
                } catch {
                    await send(.messageLoadFailed(error.localizedDescription))
                }
            }

        case .messagesLoaded(let newMessages, let hasMore):
            state.isLoading = false

            if state.cursorDate == nil {
                // 초기 로드: API에서 받은 순서 그대로 (오래된 메시지가 위, 최신 메시지가 아래)
                state.messages = newMessages
            } else {
                // 페이지네이션: 이전 메시지를 위에 추가
                state.messages = newMessages + state.messages
            }

            // 다음 페이지네이션을 위한 커서 설정
            if let oldestMessage = newMessages.last {
                state.cursorDate = oldestMessage.createdAt
            }

            state.hasMoreMessages = hasMore
            return .none

        case .messageTextChanged(let text):
            state.messageText = text
            return .none

        case .sendMessageTapped:
            guard !state.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .none
            }

            state.isSending = true
            let messageContent = state.messageText
            state.messageText = "" // 즉시 입력창 클리어

            return .run { [roomId = state.chatRoom.roomId] send in
                do {
                    let response = try await NetworkManager.shared.performRequest(
                        ChatRouter.sendMessage(roomId: roomId, content: messageContent, files: nil),
                        as: ChatMessageResponseDTO.self
                    )
                    await send(.messageSent(response.toDomain))
                } catch {
                    await send(.messageSendFailed(error.localizedDescription))
                }
            }

        case .messageSent(let message):
            state.isSending = false
            state.messages.append(message)
            return .none

        case .loadMoreMessages:
            guard !state.isLoading, state.hasMoreMessages else {
                return .none
            }

            state.isLoading = true
            return .send(.loadMessages)

        case .messageLoadFailed:
            state.isLoading = false
            // TODO: 에러 알림 표시
            return .none

        case .messageSendFailed:
            state.isSending = false
            // TODO: 에러 알림 표시
            return .none
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            self.reduce(into: &state, action: action)
        }
    }
}
