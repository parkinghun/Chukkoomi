//
//  AuthDTO.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/6/25.
//

import Foundation

// MARK: - Refresh Token Response
struct RefreshTokenResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
}

extension RefreshTokenResponseDTO {
    var toDomain: AuthToken {
        return AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
