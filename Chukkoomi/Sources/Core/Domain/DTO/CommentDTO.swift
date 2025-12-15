//
//  CommentDTO.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/10/25.
//

import Foundation

struct CommentListDTO: Decodable {
    let data: [CommentResponseDTO]
}

/// 댓글 응답 DTO
struct CommentResponseDTO: Decodable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: UserDTO
    let replies: [CommentResponseDTO]?  // 대댓글일 경우 nil
    
    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case content, createdAt, creator, replies
    }
}

extension CommentResponseDTO {
    var toDomain: Comment {
        return Comment(
            id: commentId,
            content: content,
            createdAt: DateFormatters.iso8601.date(from: createdAt) ?? Date(),
            creator: creator.toDomain)
    }
}

/// 댓글 요청 DTO
struct CommentRequestDTO: Encodable {
    let content: String
}
