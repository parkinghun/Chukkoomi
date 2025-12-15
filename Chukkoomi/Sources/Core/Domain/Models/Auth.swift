//
//  Auth.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/6/25.
//

import Foundation

// MARK: - Auth Token
struct AuthToken {
    let accessToken: String
    let refreshToken: String
}

extension AuthToken {
    var toDTO: RefreshTokenResponseDTO {
        return RefreshTokenResponseDTO(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
