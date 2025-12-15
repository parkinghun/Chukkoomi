//
//  BasicMessageResponseDTO.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

struct BasicMessageResponseDTO: Decodable {
    let message: String
}

extension BasicMessageResponseDTO {
    var toDomain: BasicMessageResponse {
        return BasicMessageResponse(message: message)
    }
}
