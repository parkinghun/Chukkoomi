//
//  UserDTO.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

struct UserDTO: Decodable {
    let user_id: String
    let nick: String
    let profileImage: String?
}

extension UserDTO {
    var toDomain: User {
        return User(userId: user_id, nickname: nick, profileImage: profileImage)
    }
}

struct UserListDTO: Decodable {
    let data: [UserDTO]
}

extension UserListDTO {
    var toDomain: [User] {
        return data.map { $0.toDomain }
    }
}
