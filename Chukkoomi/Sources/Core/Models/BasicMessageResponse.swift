//
//  BasicMessage.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

struct BasicMessageResponse {
    let message: String
}

extension BasicMessageResponse {
    var toDTO: BasicMessageResponseDTO {
        return BasicMessageResponseDTO(message: message)
    }
}
