//
//  PostResponseDTO.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/10/25.
//

import Foundation

/// 게시글 목록 조회 / 좋아요한 게시글 / 위치기반 / 검색 결과 등
struct PostListResponseDTO: Decodable {
    let data: [PostResponseDTO]
    /// next_cursor가 없는 API(위치 기반 / 검색)는 nextCursor가 nil
    let nextCursor: String?
}

/// 게시글 작성 / 수정 / 단일 조회 시 공통 응답
struct PostResponseDTO: Decodable {
    let postId: String
    let category: String
    let title: String
    let price: Int
    let content: String
    let value1: String
    let value2: String
    let value3: String
    let value4: String
    let value5: String
    let value6: String
    let value7: String
    let value8: String
    let value9: String
    let value10: String
    let createdAt: String
    let creator: UserDTO
    let files: [String]
    let likes: [String]
    let likes2: [String]
    let buyers: [String]
    let hashTags: [String]
    let commentCount: Int
    let geolocation: GeoLocationDTO?
    let distance: Double?
}

extension PostResponseDTO {
    var toDomain: Post {
        return Post(
            id: postId,
            teams: FootballTeams(rawValue: category) ?? .total,
            title: title,
            price: price,
            content: content,
            values: [value1, value2, value3, value4, value5, value6, value7, value8, value9, value10],
            createdAt: DateFormatters.iso8601.date(from: createdAt) ?? Date(),
            creator: creator.toDomain,
            files: files,
            likes: likes,
            bookmarks: likes2,
            buyers: buyers,
            hashTags: hashTags,
            commentCount: commentCount,
            location: GeoLocation(
                longitude: geolocation?.longitude ?? GeoLocation.defaultLocation.longitude,
                latitude: geolocation?.latitude ?? GeoLocation.defaultLocation.latitude
            ),
            distance: distance
        )
    }
}

struct GeoLocationDTO: Decodable {
    let longitude: Double
    let latitude: Double
}
