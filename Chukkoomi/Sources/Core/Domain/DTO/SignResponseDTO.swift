//
//  SignResponseDTO.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

struct SignResponseDTO: Decodable {
    let user_id: String
    let email: String
    let nick: String
    let profileImage: String?
    let accessToken: String
    let refreshToken: String
}

extension SignResponseDTO {
    var toDomain: SignResponse {
        return SignResponse(userId: user_id, email: email, nickname: nick, profileImage: profileImage, accessToken: accessToken, refreshToken: refreshToken)
    }
}
