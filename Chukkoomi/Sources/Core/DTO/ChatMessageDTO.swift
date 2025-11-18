//
//  ChatMessageDTO.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/6/25.
//

import Foundation

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
