//
//  ChatRoomDTO.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/6/25.
//

import Foundation
import RealmSwift

// MARK: - 채팅방 생성 Request
struct CreateChatRoomRequestDTO: Encodable {
    let opponentId: String
    
    enum CodingKeys: String, CodingKey {
        case opponentId = "opponent_id"
    }
}

// MARK: - 채팅방 Response (생성 + 리스트 공통)
struct ChatRoomResponseDTO: Decodable {
    let roomId: String
    let createdAt: String
    let updatedAt: String
    let participants: [Participant]
    let lastChat: LastChat?
    
    struct Participant: Decodable {
        let userId: String
        let nick: String
        let profileImage: String?
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case nick
            case profileImage
        }
    }
    
    struct LastChat: Decodable {
        let chatId: String
        let roomId: String
        let content: String?
        let createdAt: String
        let sender: Participant
        let files: [String]
        
        enum CodingKeys: String, CodingKey {
            case chatId = "chat_id"
            case roomId = "room_id"
            case content
            case createdAt
            case sender
            case files
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case createdAt
        case updatedAt
        case participants
        case lastChat
    }
}

// MARK: - 채팅방 리스트 Response
struct ChatRoomListResponseDTO: Decodable {
    let data: [ChatRoomResponseDTO]
}

// MARK: - DTO -> Entity
extension ChatRoomResponseDTO {
    var toDomain: ChatRoom {
        return ChatRoom(
            roomId: roomId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            participants: participants.map { $0.toDomain },
            lastChat: lastChat?.toDomain
        )
    }
}

extension ChatRoomResponseDTO.Participant {
    var toDomain: ChatUser {
        return ChatUser(
            userId: userId,
            nick: nick,
            profileImage: profileImage
        )
    }
}

extension ChatRoomResponseDTO.LastChat {
    var toDomain: LastChatMessage {
        return LastChatMessage(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: createdAt,
            sender: sender.toDomain,
            files: files
        )
    }
}

// MARK: - Realm Objects

/// Realm Object for ChatUser (Embedded) - for ChatRoom participants
final class ChatUserRealmDTO: EmbeddedObject {
    @Persisted var userId: String
    @Persisted var nick: String
    @Persisted var profileImage: String?

    convenience init(userId: String, nick: String, profileImage: String?) {
        self.init()
        self.userId = userId
        self.nick = nick
        self.profileImage = profileImage
    }
}

/// Realm Object for LastChatMessage (Embedded)
final class LastChatMessageRealmDTO: EmbeddedObject {
    @Persisted var chatId: String
    @Persisted var roomId: String
    @Persisted var content: String?
    @Persisted var createdAt: String
    @Persisted var sender: ChatUserRealmDTO?
    @Persisted var files: List<String>

    convenience init(
        chatId: String,
        roomId: String,
        content: String?,
        createdAt: String,
        sender: ChatUserRealmDTO?,
        files: [String]
    ) {
        self.init()
        self.chatId = chatId
        self.roomId = roomId
        self.content = content
        self.createdAt = createdAt
        self.sender = sender
        self.files.append(objectsIn: files)
    }
}

/// Realm Object for ChatRoom
final class ChatRoomRealmDTO: Object {
    @Persisted(primaryKey: true) var roomId: String
    @Persisted var createdAt: String
    @Persisted var updatedAt: String
    @Persisted var participants: List<ChatUserRealmDTO>
    @Persisted var lastChat: LastChatMessageRealmDTO?
    @Persisted var myUserId: String  // 현재 로그인한 사용자 ID (필터링용)

    convenience init(
        roomId: String,
        createdAt: String,
        updatedAt: String,
        participants: [ChatUserRealmDTO],
        lastChat: LastChatMessageRealmDTO?,
        myUserId: String
    ) {
        self.init()
        self.roomId = roomId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.participants.append(objectsIn: participants)
        self.lastChat = lastChat
        self.myUserId = myUserId
    }
}

// MARK: - Realm DTO -> Domain
extension ChatUserRealmDTO {
    var toDomain: ChatUser {
        return ChatUser(
            userId: userId,
            nick: nick,
            profileImage: profileImage
        )
    }
}

extension LastChatMessageRealmDTO {
    var toDomain: LastChatMessage {
        return LastChatMessage(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: createdAt,
            sender: sender?.toDomain ?? ChatUser(userId: "", nick: "", profileImage: nil),
            files: Array(files)
        )
    }
}

extension ChatRoomRealmDTO {
    var toDomain: ChatRoom {
        return ChatRoom(
            roomId: roomId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            participants: Array(participants.map { $0.toDomain }),
            lastChat: lastChat?.toDomain
        )
    }
}

// MARK: - Domain -> Realm DTO
extension ChatUser {
    func toRealmDTO() -> ChatUserRealmDTO {
        return ChatUserRealmDTO(
            userId: userId,
            nick: nick,
            profileImage: profileImage
        )
    }
}

extension LastChatMessage {
    func toRealmDTO() -> LastChatMessageRealmDTO {
        return LastChatMessageRealmDTO(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: createdAt,
            sender: sender.toRealmDTO(),
            files: files
        )
    }
}

extension ChatRoom {
    func toRealmDTO(myUserId: String) -> ChatRoomRealmDTO {
        return ChatRoomRealmDTO(
            roomId: roomId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            participants: participants.map { $0.toRealmDTO() },
            lastChat: lastChat?.toRealmDTO(),
            myUserId: myUserId
        )
    }
}
