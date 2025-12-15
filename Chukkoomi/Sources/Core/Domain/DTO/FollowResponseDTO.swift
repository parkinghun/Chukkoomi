//
//  FollowResponseDTO.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

struct FollowResponseDTO: Decodable {
    let nick: String
    let opponent_nick: String
    let following_status: Bool
}

extension FollowResponseDTO {
    var toDomain: FollowResponse {
        return FollowResponse(nickname: nick, opponentNickname: opponent_nick, status: following_status)
    }
}
