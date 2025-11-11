//
//  FixturesResponseDTO.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/11/25.
//

import Foundation

// 전체 경기 응답 DTO
struct FixturesResponseDTO: Codable {
    let response: [FixtureItemDTO]
}

extension FixturesResponseDTO {
    var toDomain: [Match] {
        return response.map {
            return Match(
                id: $0.fixture.id,
                date: DateFormatters.iso8601.date(from: $0.fixture.date) ?? Date(),
                homeTeamName: $0.teams.home.name,
                awayTeamName: $0.teams.away.name,
                homeTeamLogo: $0.teams.home.logo,
                awayTeamLogo: $0.teams.away.logo,
                homeScore: $0.goals.home,
                awayScore: $0.goals.away)
        }
    }
}

// 개별 경기 항목 DTO
struct FixtureItemDTO: Codable {
    let fixture: FixtureDTO
    let league: LeagueDTO
    let teams: TeamsDTO
    let goals: GoalsDTO
    let score: ScoreDTO
}

// 경기 상세 정보 DTO
struct FixtureDTO: Codable {
    let id: Int
    let referee: String?
    let timezone: String
    let date: String
    let timestamp: Int
    let venue: VenueDTO
    let status: StatusDTO
}

// 경기 장소 DTO
struct VenueDTO: Codable {
    let id: Int?
    let name: String?
    let city: String?
}

// 경기 상태 DTO
struct StatusDTO: Codable {
    let long: String
    let short: String
    let elapsed: Int?
    let extra: String?
}

// 리그 정보 DTO
struct LeagueDTO: Codable {
    let id: Int
    let name: String
    let country: String
    let logo: String
    let flag: String
    let season: Int
    let round: String
}

struct TeamsDTO: Codable {
    let home: TeamDTO
    let away: TeamDTO
}

struct TeamDTO: Codable {
    let id: Int
    let name: String
    let logo: String
    let winner: Bool?
}

struct GoalsDTO: Codable {
    let home: Int?
    let away: Int?
}

struct ScoreDTO: Codable {
    let halftime: GoalsDTO
    let fulltime: GoalsDTO
    let extratime: GoalsDTO
    let penalty: GoalsDTO
}
