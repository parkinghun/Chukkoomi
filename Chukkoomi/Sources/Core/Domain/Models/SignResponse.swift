//
//  SignResponse.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

struct SignResponse {
    let userId: String
    let email: String
    let nickname: String
    let profileImage: String?
    let accessToken: String
    let refreshToken: String
}

extension SignResponse {
    var toDTO: SignResponseDTO {
        return SignResponseDTO(user_id: userId, email: email, nick: nickname, profileImage: profileImage, accessToken: accessToken, refreshToken: refreshToken)
    }
}
