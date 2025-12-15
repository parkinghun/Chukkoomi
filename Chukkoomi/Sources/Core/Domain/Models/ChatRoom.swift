//
//  ChatRoom.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/6/25.
//

import Foundation

// MARK: - Chat User
struct ChatUser: Equatable {
    let userId: String
    let nick: String
    let profileImage: String?
}

// MARK: - Last Chat Message
struct LastChatMessage: Equatable {
    let chatId: String
    let roomId: String
    let content: String?
    let createdAt: String
    let sender: ChatUser
    let files: [String]
}

// MARK: - Chat Room
struct ChatRoom: Equatable {
    let roomId: String
    let createdAt: String
    let updatedAt: String
    let participants: [ChatUser]
    let lastChat: LastChatMessage?
}
