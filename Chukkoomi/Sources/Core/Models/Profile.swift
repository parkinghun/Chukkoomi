//
//  Profile.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

struct Profile {
    let userId: String
    let email: String?
    let nickname: String
    let profileImage: String?
    let introduce: String
    let followers: [User]
    let following: [User]
    let posts: [String]
}

extension Profile {
    var toDomain: ProfileDTO {
        return ProfileDTO(user_id: userId, email: email, nick: nickname, profileImage: profileImage, phoneNum: "", gender: "", birthDay: "", info1: introduce, info2: "", info3: "", info4: "", info5: "", followers: followers.map { $0.toDTO }, following: following.map { $0.toDTO }, posts: posts)
    }
}
