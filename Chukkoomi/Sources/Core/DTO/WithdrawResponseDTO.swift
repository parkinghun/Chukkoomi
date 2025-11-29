//
//  WithdrawResponseDTO.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

struct WithdrawResponseDTO: Decodable {
    let user_id: String
    let email: String
    let nick: String
}

extension WithdrawResponseDTO {
    var toDomain: WithdrawResponse {
        return WithdrawResponse(userId: user_id, email: email, nickname: nick)
    }
}
