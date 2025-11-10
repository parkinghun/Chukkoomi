//
//  ProfileDTO.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

struct ProfileDTO: Decodable {
    let user_id: String
    let email: String?
    let nick: String
    let profileImage: String?
    let phoneNum: String?
    let gender: String?
    let birthDay: String?
    let info1: String?
    let info2: String?
    let info3: String?
    let info4: String?
    let info5: String?
    let followers: [UserDTO]
    let following: [UserDTO]
    let posts: [String]
}

extension ProfileDTO {
    var toDomain: Profile {
        return Profile(userId: user_id, email: email, nickname: nick, profileImage: profileImage, introduce: info1, followers: followers.map { $0.toDomain }, following: following.map { $0.toDomain }, posts: posts)
    }
}
