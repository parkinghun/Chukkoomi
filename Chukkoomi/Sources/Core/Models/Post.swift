//
//  Post.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/5/25.
//

import Foundation

import Foundation

struct Post {
    let id: String?
    let teams: FootballTeams
    let title: String
    let price: Int
    let content: String
#warning("values - 데이터 확정 시 수정 필요")
    let values: [String]
    let createdAt: Date?
    let creator: User?
    let files: [String]
    let likes: [String]?
    let bookmarks: [String]?
    let buyers: [String]?
    let hashTags: [String]
    let commentCount: Int?
    let location: GeoLocation
    let distance: Double?
}

extension Post {
    init(
        teams: FootballTeams,
        title: String,
        price: Int,
        content: String,
        values: [String] = [],
        files: [String] = [],
        location: GeoLocation = .defaultLocation
    ) {
        self.id = nil
        self.teams = teams
        self.title = title
        self.price = price
        self.content = content
        self.values = values
        self.createdAt = nil
        self.creator = nil
        self.files = files
        self.likes = nil
        self.bookmarks = nil
        self.buyers = nil
        self.hashTags = []
        self.commentCount = nil
        self.location = location
        self.distance = nil
    }
    
    var toDTO: PostRequestDTO {
        return PostRequestDTO(
            category: teams.rawValue,
            title: title,
            price: price,
            content: content,
            value1: values.count > 0 ? values[0] : "",
            value2: values.count > 1 ? values[1] : "",
            value3: values.count > 2 ? values[2] : "",
            value4: values.count > 3 ? values[3] : "",
            value5: values.count > 4 ? values[4] : "",
            value6: values.count > 5 ? values[5] : "",
            value7: values.count > 6 ? values[6] : "",
            value8: values.count > 7 ? values[7] : "",
            value9: values.count > 8 ? values[8] : "",
            value10: values.count > 9 ? values[9] : "",
            files: files,
            longitude: location.longitude,
            latitude: location.latitude
        )
    }
}

enum FootballTeams: String, CaseIterable {
    case total = "전체"
}

struct GeoLocation {
    let longitude: Double
    let latitude: Double
    
    static let defaultLocation = GeoLocation(
        longitude: 126.886417,
        latitude: 37.517682
    )
}
