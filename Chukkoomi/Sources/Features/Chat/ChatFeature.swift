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
        var chatRoom: ChatRoom?  // 옵셔널로 변경 (첫 메시지 전송 시 생성)
        let opponent: ChatUser   // 상대방 정보
        let myUserId: String?
        var messages: [ChatMessage] = []
        var messageText: String = ""
        var isLoading: Bool = false
        var isSending: Bool = false
        var isUploadingFiles: Bool = false
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
        case chatRoomCreated(ChatRoom)
        case loadMoreMessages
        case messageLoadFailed(String)
        case messageSendFailed(String)

        // 파일 업로드
        case uploadAndSendFiles([Data])
        case filesUploaded([String])
        case fileUploadFailed(String)
    }

    // MARK: - Reducer
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isLoading = true
            return .send(.loadMessages)

        case .loadMessages:
            // 채팅방이 아직 생성되지 않은 경우 (첫 메시지 전송 전)
            guard let roomId = state.chatRoom?.roomId else {
                state.isLoading = false
                return .none
            }

            return .run { [cursorDate = state.cursorDate] send in
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

            // 채팅방이 아직 생성되지 않은 경우 (첫 메시지)
            if state.chatRoom == nil {
                return .run { [opponentId = state.opponent.userId] send in
                    do {
                        // 1. 채팅방 생성
                        let chatRoomResponse = try await NetworkManager.shared.performRequest(
                            ChatRouter.createChatRoom(opponentId: opponentId),
                            as: ChatRoomResponseDTO.self
                        )
                        let chatRoom = chatRoomResponse.toDomain
                        await send(.chatRoomCreated(chatRoom))

                        // 2. 메시지 전송
                        let messageResponse = try await NetworkManager.shared.performRequest(
                            ChatRouter.sendMessage(roomId: chatRoom.roomId, content: messageContent, files: nil),
                            as: ChatMessageResponseDTO.self
                        )
                        await send(.messageSent(messageResponse.toDomain))
                    } catch {
                        await send(.messageSendFailed(error.localizedDescription))
                    }
                }
            } else {
                // 채팅방이 이미 존재하는 경우
                return .run { [roomId = state.chatRoom!.roomId] send in
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
            }

        case .messageSent(let message):
            state.isSending = false
            state.messages.append(message)
            return .none

        case .chatRoomCreated(let chatRoom):
            state.chatRoom = chatRoom
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

        case .uploadAndSendFiles(let filesData):
            state.isUploadingFiles = true

            // 채팅방이 아직 생성되지 않은 경우 (첫 메시지)
            if state.chatRoom == nil {
                return .run { [opponentId = state.opponent.userId] send in
                    do {
                        // 1. 채팅방 생성
                        let chatRoomResponse = try await NetworkManager.shared.performRequest(
                            ChatRouter.createChatRoom(opponentId: opponentId),
                            as: ChatRoomResponseDTO.self
                        )
                        let chatRoom = chatRoomResponse.toDomain
                        await send(.chatRoomCreated(chatRoom))

                        // 2. 파일 업로드 재시도
                        await send(.uploadAndSendFiles(filesData))
                    } catch {
                        await send(.fileUploadFailed(error.localizedDescription))
                    }
                }
            }

            return .run { [roomId = state.chatRoom!.roomId] send in
                do {
                    // Data를 MultipartFile 배열로 변환
                    let multipartFiles = filesData.enumerated().map { index, data in
                        // 파일 확장자 결정 (간단하게 JPEG로 가정, 실제로는 MIME 타입 체크 필요)
                        let fileName = "image_\(index)_\(UUID().uuidString).jpg"
                        return MultipartFile(data: data, fileName: fileName, mimeType: "image/jpeg")
                    }

                    // 파일 업로드 (ChatRouter 사용)
                    let response = try await NetworkManager.shared.performRequest(
                        ChatRouter.uploadFiles(roomId: roomId, files: multipartFiles),
                        as: UploadFileResponseDTO.self
                    )

                    // 업로드된 파일 URL로 메시지 전송
                    await send(.filesUploaded(response.files))
                } catch {
                    await send(.fileUploadFailed(error.localizedDescription))
                }
            }

        case .filesUploaded(let fileUrls):
            state.isUploadingFiles = false

            // 파일 URL로 메시지 전송
            guard let roomId = state.chatRoom?.roomId else {
                return .none
            }

            return .run { send in
                do {
                    let response = try await NetworkManager.shared.performRequest(
                        ChatRouter.sendMessage(roomId: roomId, content: nil, files: fileUrls),
                        as: ChatMessageResponseDTO.self
                    )
                    await send(.messageSent(response.toDomain))
                } catch {
                    await send(.messageSendFailed(error.localizedDescription))
                }
            }

        case .fileUploadFailed:
            state.isUploadingFiles = false
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
