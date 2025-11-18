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
        var pendingFileUploads: [String: [Data]] = [:]  // localId: filesData
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case loadMessages
        case messagesLoaded([ChatMessage], hasMore: Bool)
        case messageTextChanged(String)
        case sendMessageTapped
        case messageSent(ChatMessage, localId: String?)
        case chatRoomCreated(ChatRoom)
        case loadMoreMessages
        case messageLoadFailed(String)
        case messageSendFailed(String, localId: String)

        // 파일 업로드
        case uploadAndSendFiles([Data])
        case filesUploaded([String], localId: String)
        case fileUploadFailed(String, localId: String?)
        case uploadTimeout(localId: String)

        // 메시지 재전송 및 취소
        case retryMessage(localId: String)
        case cancelMessage(localId: String)
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

            // 로컬 임시 메시지 생성 (낙관적 업데이트)
            let localId = UUID().uuidString
            let tempMessage = ChatMessage(
                chatId: "",  // 서버 응답 후 업데이트
                roomId: state.chatRoom?.roomId ?? "",
                content: messageContent,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                sender: ChatUser(
                    userId: state.myUserId ?? "",
                    nick: "",  // UI에서는 내 메시지는 닉네임을 표시하지 않음
                    profileImage: nil
                ),
                files: [],
                sendStatus: .sending,
                localId: localId,
                localImages: nil
            )
            state.messages.append(tempMessage)

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
                        await send(.messageSent(messageResponse.toDomain, localId: localId))
                    } catch {
                        await send(.messageSendFailed(error.localizedDescription, localId: localId))
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
                        await send(.messageSent(response.toDomain, localId: localId))
                    } catch {
                        await send(.messageSendFailed(error.localizedDescription, localId: localId))
                    }
                }
            }

        case .messageSent(let message, let localId):
            state.isSending = false

            // localId가 있으면 임시 메시지를 교체, 없으면 새로 추가 (페이지네이션으로 로드된 메시지)
            if let localId = localId,
               let index = state.messages.firstIndex(where: { $0.localId == localId }) {
                state.messages[index] = message
                // 파일 Data 정리
                state.pendingFileUploads.removeValue(forKey: localId)
            } else {
                state.messages.append(message)
            }
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

        case .messageSendFailed(_, let localId):
            state.isSending = false

            // localId로 메시지를 찾아서 상태를 .failed로 변경
            if let index = state.messages.firstIndex(where: { $0.localId == localId }) {
                var failedMessage = state.messages[index]
                failedMessage.sendStatus = .failed
                state.messages[index] = failedMessage
            }
            return .none

        case .uploadAndSendFiles(let filesData):
            state.isUploadingFiles = true

            // 로컬 임시 메시지 생성 (낙관적 업데이트)
            let localId = UUID().uuidString
            let fileCount = filesData.count
            let tempMessage = ChatMessage(
                chatId: "",
                roomId: state.chatRoom?.roomId ?? "",
                content: nil,  // 파일 메시지는 content를 nil로
                createdAt: ISO8601DateFormatter().string(from: Date()),
                sender: ChatUser(
                    userId: state.myUserId ?? "",
                    nick: "",
                    profileImage: nil
                ),
                files: ["uploading"],  // 업로드 중 표시를 위한 placeholder
                sendStatus: .sending,
                localId: localId,
                localImages: filesData  // 로컬 이미지 Data 저장
            )
            state.messages.append(tempMessage)

            // 파일 Data 저장 (재전송 시 사용)
            state.pendingFileUploads[localId] = filesData

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
                        await send(.fileUploadFailed(error.localizedDescription, localId: localId))
                    }
                }
            }

            return .merge(
                // 실제 파일 업로드
                .run { [roomId = state.chatRoom!.roomId] send in
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
                        await send(.filesUploaded(response.files, localId: localId))
                    } catch {
                        await send(.fileUploadFailed(error.localizedDescription, localId: localId))
                    }
                }
                .cancellable(id: localId, cancelInFlight: true),

                // 5초 타임아웃
                .run { send in
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    await send(.uploadTimeout(localId: localId))
                }
                .cancellable(id: "\(localId)-timeout", cancelInFlight: true)
            )

        case .filesUploaded(let fileUrls, let localId):
            state.isUploadingFiles = false

            // 파일 URL로 메시지 전송
            guard let roomId = state.chatRoom?.roomId else {
                return .none
            }

            // 타임아웃 취소
            return .merge(
                .cancel(id: localId),
                .cancel(id: "\(localId)-timeout"),
                .run { send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            ChatRouter.sendMessage(roomId: roomId, content: nil, files: fileUrls),
                            as: ChatMessageResponseDTO.self
                        )
                        await send(.messageSent(response.toDomain, localId: localId))
                    } catch {
                        await send(.messageSendFailed(error.localizedDescription, localId: localId))
                    }
                }
            )

        case .fileUploadFailed(_, let localId):
            state.isUploadingFiles = false

            // localId로 메시지를 찾아서 상태를 .failed로 변경
            if let localId = localId,
               let index = state.messages.firstIndex(where: { $0.localId == localId }) {
                var failedMessage = state.messages[index]
                failedMessage.sendStatus = .failed
                state.messages[index] = failedMessage

                // 타임아웃 취소
                return .merge(
                    .cancel(id: localId),
                    .cancel(id: "\(localId)-timeout")
                )
            }
            return .none

        case .uploadTimeout(let localId):
            state.isUploadingFiles = false

            // localId로 메시지를 찾아서 상태를 .failed로 변경
            if let index = state.messages.firstIndex(where: { $0.localId == localId }) {
                var failedMessage = state.messages[index]
                failedMessage.sendStatus = .failed
                state.messages[index] = failedMessage
            }

            // 업로드 태스크 취소
            return .cancel(id: localId)

        case .retryMessage(let localId):
            // localId로 실패한 메시지를 찾아서 재전송
            guard let index = state.messages.firstIndex(where: { $0.localId == localId }),
                  let roomId = state.chatRoom?.roomId else {
                return .none
            }

            let failedMessage = state.messages[index]

            // 상태를 .sending으로 변경
            var retryingMessage = failedMessage
            retryingMessage.sendStatus = .sending
            state.messages[index] = retryingMessage

            // 파일 업로드가 실패한 경우 (pendingFileUploads에 Data가 있음)
            if let filesData = state.pendingFileUploads[localId] {
                return .run { send in
                    await send(.uploadAndSendFiles(filesData))
                    // 기존 실패 메시지 삭제
                    await send(.cancelMessage(localId: localId))
                }
            }

            // 텍스트 메시지 재전송
            let content = failedMessage.content
            let files = failedMessage.files

            return .run { send in
                do {
                    let response = try await NetworkManager.shared.performRequest(
                        ChatRouter.sendMessage(roomId: roomId, content: content, files: files.isEmpty ? nil : files),
                        as: ChatMessageResponseDTO.self
                    )
                    await send(.messageSent(response.toDomain, localId: localId))
                } catch {
                    await send(.messageSendFailed(error.localizedDescription, localId: localId))
                }
            }

        case .cancelMessage(let localId):
            // localId로 실패한 메시지를 찾아서 삭제
            state.messages.removeAll { $0.localId == localId }
            // 파일 Data도 정리
            state.pendingFileUploads.removeValue(forKey: localId)
            return .none
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            self.reduce(into: &state, action: action)
        }
    }
}
