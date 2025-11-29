//
//  PostLikeResponseDTO.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import Foundation

/// 좋아요/북마크 토글 응답
struct PostLikeResponseDTO: Decodable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}
