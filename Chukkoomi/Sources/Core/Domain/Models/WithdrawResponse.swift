//
//  WithdrawResponse.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

struct WithdrawResponse {
    let userId: String
    let email: String
    let nickname: String
}

extension WithdrawResponse {
    var toDTO: WithdrawResponseDTO {
        return WithdrawResponseDTO(user_id: userId, email: email, nick: nickname)
    }
}
