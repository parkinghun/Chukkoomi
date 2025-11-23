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

    // content에서 게시물 공유 정보 파싱
    var sharedPost: SharedPost? {
        guard let content = content,
              content.hasPrefix("[SHARED_POST]") else {
            return nil
        }

        // "[SHARED_POST]postId:xxx|content:xxx|files:file1,file2|creatorNick:xxx|creatorProfileImage:xxx" 형식 파싱
        let parts = content.dropFirst("[SHARED_POST]".count).split(separator: "|")
        var postId: String?
        var postContent: String?
        var postFiles: [String] = []
        var creatorNick: String?
        var creatorProfileImage: String?

        for part in parts {
            let keyValue = part.split(separator: ":", maxSplits: 1)
            guard keyValue.count == 2 else { continue }

            let key = String(keyValue[0])
            let value = String(keyValue[1])

            switch key {
            case "postId":
                postId = value
            case "content":
                postContent = value
            case "files":
                postFiles = value.split(separator: ",").map { String($0) }
            case "creatorNick":
                creatorNick = value
            case "creatorProfileImage":
                creatorProfileImage = value
            default:
                break
            }
        }

        guard let postId = postId else { return nil }

        return SharedPost(
            postId: postId,
            content: postContent,
            files: postFiles,
            creatorNick: creatorNick,
            creatorProfileImage: creatorProfileImage
        )
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
        // 게시물 공유 메시지인 경우 content를 nil로 설정
        let actualContent: String?
        if sharedPost != nil {
            actualContent = nil
        } else {
            actualContent = content
        }

        return ChatMessage(
            chatId: chatId,
            roomId: roomId,
            content: actualContent,
            createdAt: createdAt,
            sender: sender.toDomain,
            files: files,
            sendStatus: .sent,  // 서버에서 받은 메시지는 전송 완료 상태
            localId: nil,  // 서버에서 받은 메시지는 localId 없음
            localImages: nil,  // 서버에서 받은 메시지는 로컬 이미지 없음
            sharedPost: sharedPost  // 파싱된 게시물 정보
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
    @Persisted var sharedPostData: String?  // JSON 인코딩된 SharedPost 데이터

    convenience init(
        chatId: String,
        roomId: String,
        content: String?,
        createdAt: String,
        sender: ChatUserRealmDTO?,
        files: [String],
        sendStatus: String,
        sharedPostData: String? = nil
    ) {
        self.init()
        self.chatId = chatId
        self.roomId = roomId
        self.content = content
        self.createdAt = createdAt
        self.sender = sender
        self.files.append(objectsIn: files)
        self.sendStatus = sendStatus
        self.sharedPostData = sharedPostData
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

        // sharedPostData JSON 디코딩
        var sharedPost: SharedPost? = nil
        if let jsonData = sharedPostData?.data(using: .utf8) {
            sharedPost = try? JSONDecoder().decode(SharedPost.self, from: jsonData)
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
            localImages: nil,
            sharedPost: sharedPost
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

        // sharedPost JSON 인코딩
        var sharedPostJson: String? = nil
        if let sharedPost = sharedPost,
           let jsonData = try? JSONEncoder().encode(sharedPost),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sharedPostJson = jsonString
        }

        return ChatMessageRealmDTO(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: createdAt,
            sender: sender.toRealmDTO(),
            files: files,
            sendStatus: statusString,
            sharedPostData: sharedPostJson
        )
    }
}
