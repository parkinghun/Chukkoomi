//
//  MatchDetailDTO.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/25/25.
//

import Foundation

struct MatchDetailListDTO: Decodable {
    let data: [MatchDetailDTO]
}

struct MatchDetailDTO: Decodable {
    let postId: String
    let category: String
    let title: String
    let price: Int
    let content: String
    let value1: String?
    let value2: String?
    let value3: String?
    let value4: String?
    let value5: String?
    let value6: String?
    let value7: String?
    let value8: String?
    let value9: String?
    let value10: String?
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

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case category
        case title
        case price
        case content
        case value1
        case value2
        case value3
        case value4
        case value5
        case value6
        case value7
        case value8
        case value9
        case value10
        case createdAt
        case creator
        case files
        case likes
        case likes2
        case buyers
        case hashTags
        case commentCount = "comment_count"
        case geolocation
        case distance
    }
}

extension MatchDetailListDTO {
    var toDomain: MatchDetail {
        get throws {
            guard let detail = data.first else {
                throw NSError(
                    domain: "MatchDetailDTO",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "경기를 찾을 수 없습니다."]
                )
            }

            let homeDefends: [Player] = parsePlayers(detail.value2)
            let homeMidFields: [Player] = parsePlayers(detail.value3)
            let homeForwards: [Player] = parsePlayers(detail.value4)
            let awayDefends: [Player] = parsePlayers(detail.value6)
            let awayMidFields: [Player] = parsePlayers(detail.value7)
            let awayForwards: [Player] = parsePlayers(detail.value8)

            let homeUniform: String = detail.files.first ?? ""
            let awayUniform: String = detail.files.last ?? ""

            return MatchDetail(
                id: detail.title,
                homeKeeper: parsePlayer(detail.value1),
                homeDefends: homeDefends,
                homeMidFields: homeMidFields,
                homeForwards: homeForwards,
                awayKeeper: parsePlayer(detail.value5),
                awayDefends: awayDefends,
                awayMidFields: awayMidFields,
                awayForwards: awayForwards,
                homeUniform: homeUniform,
                awayUniform: awayUniform
            )
        }
    }
    
    // Helper function to parse player string
    private func parsePlayers(_ value: String?) -> [Player] {
        guard let value = value else { return [] }
        return value.split(separator: ",").compactMap { playerString in
            let components = playerString.trimmingCharacters(in: .whitespaces).split(separator: " ")
            guard components.count >= 2,
                  let number = Int(components[0]) else { return nil }
            let name = components[1...].joined(separator: " ")
            return Player(id: UUID().uuidString, number: number, name: name)
        }
    }

    // Helper function to parse single player
    private func parsePlayer(_ value: String?) -> Player {
        guard let value = value else { return Player(id: UUID().uuidString, number: 0, name: "") }
        let components = value.trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard components.count >= 2,
              let number = Int(components[0]) else { return Player(id: UUID().uuidString, number: 0, name: value) }
        let name = components[1...].joined(separator: " ")
        return Player(id: UUID().uuidString, number: number, name: name)
    }
}
