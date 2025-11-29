//
//  ChatMessage.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/6/25.
//

import Foundation

// MARK: - Send Status
enum MessageSendStatus: Equatable {
    case sending    // 전송 중
    case sent       // 전송 완료
    case failed     // 전송 실패
}

// MARK: - Shared Post
struct SharedPost: Equatable, Codable {
    let postId: String
    let content: String?
    let files: [String]
    let creatorNick: String?
    let creatorProfileImage: String?
}

// MARK: - Chat Message
struct ChatMessage: Equatable {
    let chatId: String
    let roomId: String
    let content: String?
    let createdAt: String
    let sender: ChatUser  // ChatRoomEntity에서 정의된 ChatUser 사용
    let files: [String]
    var sendStatus: MessageSendStatus  // 전송 상태
    let localId: String?  // 로컬 임시 ID (서버 응답 전 사용)
    var localImages: [Data]?  // 업로드 중인 로컬 이미지 Data
    let sharedPost: SharedPost?  // 공유된 게시물 정보

    // 고유 ID (localId가 있으면 localId, 없으면 chatId 사용)
    var uniqueId: String {
        return localId ?? chatId
    }

    // 게시물 공유 메시지인지 확인
    var isSharedPost: Bool {
        return sharedPost != nil
    }
}
