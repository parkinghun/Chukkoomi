//
//  ChatMessageDTO.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/6/25.
//

import Foundation
import RealmSwift

// MARK: - 메시지 보내기 Request
struct SendMessageRequestDTO: Encodable {
    let content: String?
    let files: [String]?
}

// MARK: - 메시지 Response (보내기 + 내역 공통)
struct ChatMessageResponseDTO: Decodable {
    let chatId: String
    let roomId: String
    let content: String?
    let createdAt: String
    let sender: Sender
    let files: [String]
    
    struct Sender: Decodable {
        let userId: String
        let nick: String
        let profileImage: String?
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case nick
            case profileImage
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case roomId = "room_id"
        case content
        case createdAt
        case sender
        case files
    }
}

// MARK: - 메시지 내역 Response
struct ChatMessageListResponseDTO: Decodable {
    let data: [ChatMessageResponseDTO]
}

// MARK: - 파일 업로드 Response
struct UploadFileResponseDTO: Decodable {
    let files: [String]
}

// MARK: - DTO -> Entity
extension ChatMessageResponseDTO {
    var toDomain: ChatMessage {
        return ChatMessage(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: createdAt,
            sender: sender.toDomain,
            files: files,
            sendStatus: .sent,  // 서버에서 받은 메시지는 전송 완료 상태
            localId: nil,  // 서버에서 받은 메시지는 localId 없음
            localImages: nil  // 서버에서 받은 메시지는 로컬 이미지 없음
        )
    }
}

extension ChatMessageResponseDTO.Sender {
    var toDomain: ChatUser {
        return ChatUser(
            userId: userId,
            nick: nick,
            profileImage: profileImage
        )
    }
}

extension UploadFileResponseDTO {
    var toDomain: [String] {
        return files
    }
}

// MARK: - Realm Objects

/// Realm Object for ChatMessage
final class ChatMessageRealmDTO: Object {
    @Persisted(primaryKey: true) var chatId: String
    @Persisted var roomId: String
    @Persisted var content: String?
    @Persisted var createdAt: String
    @Persisted var sender: ChatUserRealmDTO?
    @Persisted var files: List<String>
    @Persisted var sendStatus: String  // "sending", "sent", "failed"

    convenience init(
        chatId: String,
        roomId: String,
        content: String?,
        createdAt: String,
        sender: ChatUserRealmDTO?,
        files: [String],
        sendStatus: String
    ) {
        self.init()
        self.chatId = chatId
        self.roomId = roomId
        self.content = content
        self.createdAt = createdAt
        self.sender = sender
        self.files.append(objectsIn: files)
        self.sendStatus = sendStatus
    }
}

// MARK: - Realm DTO -> Domain
extension ChatMessageRealmDTO {
    var toDomain: ChatMessage {
        let status: MessageSendStatus
        switch sendStatus {
        case "sending":
            status = .sending
        case "failed":
            status = .failed
        default:
            status = .sent
        }

        return ChatMessage(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: createdAt,
            sender: sender?.toDomain ?? ChatUser(userId: "", nick: "", profileImage: nil),
            files: Array(files),
            sendStatus: status,
            localId: nil,  // Realm에서 로드한 메시지는 localId 없음
            localImages: nil
        )
    }
}

// MARK: - Domain -> Realm DTO
extension ChatMessage {
    func toRealmDTO() -> ChatMessageRealmDTO {
        let statusString: String
        switch sendStatus {
        case .sending:
            statusString = "sending"
        case .sent:
            statusString = "sent"
        case .failed:
            statusString = "failed"
        }

        return ChatMessageRealmDTO(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: createdAt,
            sender: sender.toRealmDTO(),
            files: files,
            sendStatus: statusString
        )
    }
}
