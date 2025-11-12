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
        return response.compactMap { item in
            // API date 문자열 확인
            let dateString = item.fixture.date

            // 유연한 날짜 파싱 시도
            guard let parsedDate = DateFormatters.parseDate(dateString) else {
                print("날짜 파싱 실패: '\(dateString)'")
                print("   Fixture ID: \(item.fixture.id)")
                print("   홈팀: \(item.teams.home.name) vs 원정팀: \(item.teams.away.name)")
                return nil  // 파싱 실패 시 해당 경기 제외
            }

            return Match(
                id: item.fixture.id,
                date: parsedDate,
                homeTeamName: item.teams.home.name,
                awayTeamName: item.teams.away.name,
//                homeTeamLogo: item.teams.home.logo,
//                awayTeamLogo: item.teams.away.logo,
                homeScore: item.goals.home,
                awayScore: item.goals.away
            )
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
