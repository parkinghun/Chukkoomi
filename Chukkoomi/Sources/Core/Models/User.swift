//
//  User.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/5/25.
//

struct User: Equatable {
    let userId: String
    let nickname: String
    let profileImage: String?
}

extension User {
    var toDTO: UserDTO {
        return UserDTO(user_id: userId, nick: nickname, profileImage: profileImage)
    }
}
