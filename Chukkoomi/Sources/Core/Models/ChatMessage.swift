//
//  ChatMessage.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/6/25.
//

import Foundation

// MARK: - Chat Message
struct ChatMessage: Equatable {
    let chatId: String
    let roomId: String
    let content: String?
    let createdAt: String
    let sender: ChatUser  // ChatRoomEntity에서 정의된 ChatUser 사용
    let files: [String]
}
