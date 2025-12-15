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
    // 경기 목록을 Match 배열로 변환
    var toMatches: [Match] {
        data.compactMap { dto in
            // title 파싱: "경기ID|홈팀이름|원정팀이름|날짜(ISO8601)"
            let titleComponents = dto.title.split(separator: "|")
            guard titleComponents.count == 4 else { return nil }

            let matchId = Int(titleComponents[0]) ?? -1
            let homeTeamName = String(titleComponents[1])
            let awayTeamName = String(titleComponents[2])
            let dateString = String(titleComponents[3])

            // ISO8601 날짜 파싱
            let dateFormatter = ISO8601DateFormatter()
            guard let matchDate = dateFormatter.date(from: dateString) else { return nil }

            // 이벤트 파싱
            let homeEvents = parseMatchEvents(dto.value9, isHomeTeam: true)
            let awayEvents = parseMatchEvents(dto.value10, isHomeTeam: false)
            let allEvents = homeEvents + awayEvents

            // 골 이벤트를 세서 스코어 계산
            let homeScore = homeEvents.filter { $0.type == .goal }.count
            let awayScore = awayEvents.filter { $0.type == .goal }.count

            // 선수 라인업 파싱 (MatchDetail)
            let matchDetail = parseMatchDetail(
                dto: dto,
                matchId: String(matchId),
                homeTeamName: homeTeamName,
                awayTeamName: awayTeamName,
                matchDate: matchDate
            )

            return Match(
                id: matchId,
                date: matchDate,
                homeTeamName: homeTeamName,
                awayTeamName: awayTeamName,
                homeScore: homeScore,
                awayScore: awayScore,
                events: allEvents,
                matchDetail: matchDetail
            )
        }
    }

    // MatchDetail 파싱 헬퍼
    private func parseMatchDetail(dto: MatchDetailDTO, matchId: String, homeTeamName: String, awayTeamName: String, matchDate: Date) -> MatchDetail? {
        // value1-8이 모두 nil이면 라인업 정보가 없는 것으로 판단
        guard dto.value1 != nil || dto.value2 != nil else { return nil }

        let homeDefends: [Player] = parsePlayers(dto.value2)
        let homeMidFields: [Player] = parsePlayers(dto.value3)
        let homeForwards: [Player] = parsePlayers(dto.value4)
        let awayDefends: [Player] = parsePlayers(dto.value6)
        let awayMidFields: [Player] = parsePlayers(dto.value7)
        let awayForwards: [Player] = parsePlayers(dto.value8)

        let homeUniform: String = dto.files.first ?? ""
        let awayUniform: String = dto.files.last ?? ""

        return MatchDetail(
            id: matchId,
            homeTeamName: homeTeamName,
            awayTeamName: awayTeamName,
            matchDate: matchDate,
            homeKeeper: parsePlayer(dto.value1),
            homeDefends: homeDefends,
            homeMidFields: homeMidFields,
            homeForwards: homeForwards,
            awayKeeper: parsePlayer(dto.value5),
            awayDefends: awayDefends,
            awayMidFields: awayMidFields,
            awayForwards: awayForwards,
            homeUniform: homeUniform,
            awayUniform: awayUniform
        )
    }

    var toDomain: (matchDetail: MatchDetail, homeEvents: [MatchEvent], awayEvents: [MatchEvent]) {
        get throws {
            guard let detail = data.first else {
                throw NSError(
                    domain: "MatchDetailDTO",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "경기를 찾을 수 없습니다."]
                )
            }

            // title 파싱: "경기ID|홈팀이름|원정팀이름|날짜(ISO8601)"
            let titleComponents = detail.title.split(separator: "|")
            guard titleComponents.count == 4 else {
                throw NSError(
                    domain: "MatchDetailDTO",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "title 형식이 올바르지 않습니다. 형식: 경기ID|홈팀이름|원정팀이름|날짜"]
                )
            }

            let matchId = String(titleComponents[0])
            let homeTeamName = String(titleComponents[1])
            let awayTeamName = String(titleComponents[2])
            let dateString = String(titleComponents[3])

            // ISO8601 날짜 파싱
            let dateFormatter = ISO8601DateFormatter()
            guard let matchDate = dateFormatter.date(from: dateString) else {
                throw NSError(
                    domain: "MatchDetailDTO",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "날짜 형식이 올바르지 않습니다. ISO8601 형식을 사용하세요."]
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

            let matchDetail = MatchDetail(
                id: matchId,
                homeTeamName: homeTeamName,
                awayTeamName: awayTeamName,
                matchDate: matchDate,
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

            let homeEvents: [MatchEvent] = parseMatchEvents(detail.value9, isHomeTeam: true)
            let awayEvents: [MatchEvent] = parseMatchEvents(detail.value10, isHomeTeam: false)

            return (matchDetail: matchDetail, homeEvents: homeEvents, awayEvents: awayEvents)
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

    // Helper function to parse match events
    // 포맷: "type|playerId|playerNumber|playerName|minute,type|playerId|playerNumber|playerName|minute,..."
    private func parseMatchEvents(_ value: String?, isHomeTeam: Bool) -> [MatchEvent] {
        guard let value = value, !value.isEmpty else { return [] }

        return value.split(separator: ",").compactMap { eventString in
            let components = eventString.trimmingCharacters(in: .whitespaces).split(separator: "|")
            guard components.count == 5,
                  let playerNumber = Int(components[2]),
                  let minute = Int(components[4]) else { return nil }

            let typeString = String(components[0])
            let playerId = String(components[1])
            let playerName = String(components[3])

            guard let eventType = MatchEventType(rawValue: typeString) else { return nil }

            let player = Player(id: playerId, number: playerNumber, name: playerName)
            return MatchEvent(type: eventType, player: player, minute: minute, isHomeTeam: isHomeTeam)
        }
    }
}
