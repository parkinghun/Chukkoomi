//
//  FollowResponse.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

struct FollowResponse {
    let nickname: String
    let opponentNickname: String
    let status: Bool
}

extension FollowResponse {
    var toDTO: FollowResponseDTO {
        return FollowResponseDTO(nick: nickname, opponent_nick: opponentNickname, following_status: status)
    }
}
