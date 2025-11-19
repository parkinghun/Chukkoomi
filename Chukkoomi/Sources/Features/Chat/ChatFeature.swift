//
//  ChatFeature.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/12/25.
//

import ComposableArchitecture
import Foundation
import RealmSwift

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
        case messagesLoadedFromRealm([ChatMessage])
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
            // 채팅방이 없으면 (첫 메시지 전송 전) 로딩하지 않음
            guard let roomId = state.chatRoom?.roomId else {
                return .none
            }

            // 1. Realm에서 먼저 로드 (빠른 UI 표시)
            return .run { send in
                _ = await MainActor.run {
                    do {
                        let realm = try Realm()
                        let messageDTOs = realm.objects(ChatMessageRealmDTO.self)
                            .filter("roomId == %@", roomId)
                            .sorted(byKeyPath: "createdAt", ascending: true)
                        let messages = Array(messageDTOs.map { $0.toDomain })

                        Task {
                            send(.messagesLoadedFromRealm(messages))
                            // 2. Realm 로드 후 HTTP로 동기화
                            send(.loadMessages)
                        }
                    } catch {
                        print("Realm 메시지 로드 실패: \(error)")
                        // Realm 실패 시 HTTP로 직접 로드
                        Task {
                            send(.loadMessages)
                        }
                    }
                }
            }

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

        case .messagesLoadedFromRealm(let realmMessages):
            // Realm에서 로드한 메시지를 먼저 표시 (빠른 UX)
            state.messages = realmMessages
            state.isLoading = true  // HTTP 동기화 중임을 표시
            return .none

        case .messagesLoaded(let newMessages, let hasMore):
            state.isLoading = false

            if state.cursorDate == nil {
                // 초기 로드: API에서 받은 순서 그대로 (오래된 메시지가 위, 최신 메시지가 아래)
                // Realm에서 이미 로드했다면 병합 (중복 제거)
                if !state.messages.isEmpty {
                    // 기존 Realm 메시지와 새 메시지 병합 (chatId 기준 중복 제거)
                    let existingIds = Set(state.messages.map { $0.chatId })
                    let uniqueNewMessages = newMessages.filter { !existingIds.contains($0.chatId) }
                    state.messages.append(contentsOf: uniqueNewMessages)
                } else {
                    state.messages = newMessages
                }
            } else {
                // 페이지네이션: 이전 메시지를 위에 추가
                state.messages = newMessages + state.messages
            }

            // 다음 페이지네이션을 위한 커서 설정
            if let oldestMessage = newMessages.last {
                state.cursorDate = oldestMessage.createdAt
            }

            state.hasMoreMessages = hasMore

            // Realm에 저장
            return .run { send in
                _ = await MainActor.run {
                    do {
                        let realm = try Realm()
                        try realm.write {
                            for message in newMessages {
                                let messageDTO = message.toRealmDTO()
                                realm.add(messageDTO, update: .modified)
                            }
                        }
                    } catch {
                        print("Realm 메시지 저장 실패: \(error)")
                    }
                }
            }

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

            // Realm에 저장
            return .run { send in
                _ = await MainActor.run {
                    do {
                        let realm = try Realm()
                        let messageDTO = message.toRealmDTO()
                        try realm.write {
                            realm.add(messageDTO, update: .modified)
                        }
                    } catch {
                        print("Realm 메시지 저장 실패: \(error)")
                    }
                }
            }

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
            print("📤 uploadAndSendFiles 액션 수신: \(filesData.count)개 파일, 총 \(filesData.reduce(0) { $0 + $1.count }) bytes")
            state.isUploadingFiles = true

            // 로컬 임시 메시지 생성 (낙관적 업데이트)
            let localId = UUID().uuidString
            print("📤 임시 메시지 생성: localId = \(localId)")
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
            print("📤 임시 메시지 추가됨: 전체 메시지 수 = \(state.messages.count)")

            // 파일 Data 저장 (재전송 시 사용)
            state.pendingFileUploads[localId] = filesData

            // 채팅방이 아직 생성되지 않은 경우 (첫 메시지)
            if state.chatRoom == nil {
                print("⚠️ 채팅방이 없음. 채팅방 생성 먼저 진행")
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
                    print("📤 파일 업로드 시작: roomId = \(roomId)")
                    do {
                        // Data를 MultipartFile 배열로 변환
                        let multipartFiles = filesData.enumerated().map { index, data in
                            // 파일 타입 감지 (이미지 vs 영상)
                            let isVideo = isVideoData(data)
                            let fileName: String
                            let mimeType: String

                            if isVideo {
                                fileName = "video_\(index)_\(UUID().uuidString).mp4"
                                mimeType = "video/mp4"
                                print("📤 영상 파일 감지: \(fileName)")
                            } else {
                                fileName = "image_\(index)_\(UUID().uuidString).jpg"
                                mimeType = "image/jpeg"
                                print("📤 이미지 파일 감지: \(fileName)")
                            }

                            return MultipartFile(data: data, fileName: fileName, mimeType: mimeType)
                        }

                        // 파일 업로드 (ChatRouter 사용)
                        print("📤 서버에 파일 업로드 요청 중...")
                        let response = try await NetworkManager.shared.performRequest(
                            ChatRouter.uploadFiles(roomId: roomId, files: multipartFiles),
                            as: UploadFileResponseDTO.self
                        )

                        print("✅ 파일 업로드 성공: \(response.files.count)개 파일")
                        print("✅ 파일 URLs: \(response.files)")
                        // 업로드된 파일 URL로 메시지 전송
                        await send(.filesUploaded(response.files, localId: localId))
                    } catch {
                        print("❌ 파일 업로드 실패: \(error.localizedDescription)")
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
            print("✅ filesUploaded 액션 수신: \(fileUrls.count)개 파일, localId = \(localId)")
            state.isUploadingFiles = false

            // 파일 URL로 메시지 전송
            guard let roomId = state.chatRoom?.roomId else {
                print("⚠️ roomId가 없음")
                return .none
            }
            print("✅ 메시지 전송 시작: roomId = \(roomId)")

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

        case .fileUploadFailed(let error, let localId):
            print("❌ fileUploadFailed 액션 수신: error = \(error), localId = \(String(describing: localId))")
            state.isUploadingFiles = false

            // localId로 메시지를 찾아서 상태를 .failed로 변경
            if let localId = localId,
               let index = state.messages.firstIndex(where: { $0.localId == localId }) {
                print("❌ 메시지 상태를 failed로 변경: index = \(index)")
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

// MARK: - Helper Functions
/// Data의 첫 바이트를 확인하여 영상 파일인지 판단
private func isVideoData(_ data: Data) -> Bool {
    guard data.count > 12 else { return false }

    // MP4 시그니처 확인 (ftyp)
    let mp4Signature: [UInt8] = [0x66, 0x74, 0x79, 0x70]  // "ftyp"
    if data.count >= 8 {
        let bytes = [UInt8](data[4..<8])
        if bytes == mp4Signature {
            return true
        }
    }

    // MOV 시그니처 확인 (moov, mdat 등)
    let movSignatures: [[UInt8]] = [
        [0x6D, 0x6F, 0x6F, 0x76],  // "moov"
        [0x6D, 0x64, 0x61, 0x74],  // "mdat"
        [0x77, 0x69, 0x64, 0x65],  // "wide"
    ]

    for signature in movSignatures {
        if data.count >= 8 {
            let bytes = [UInt8](data[4..<8])
            if bytes == signature {
                return true
            }
        }
    }

    return false
}
