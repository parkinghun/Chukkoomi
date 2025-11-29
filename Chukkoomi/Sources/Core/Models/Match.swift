//
//  Match.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/11/25.
//

import Foundation

// MARK: - Match Event Types
enum MatchEventType: String, Codable, Equatable {
    case goal = "Goal"
    case yellowCard = "Yellow Card"
    case redCard = "Red Card"
}

// MARK: - Match Event
struct MatchEvent: Identifiable, Equatable, Codable {
    let id: UUID
    let type: MatchEventType
    let player: Player
    let minute: Int
    let isHomeTeam: Bool // true면 홈팀, false면 원정팀

    init(id: UUID = UUID(), type: MatchEventType, player: Player, minute: Int, isHomeTeam: Bool) {
        self.id = id
        self.type = type
        self.player = player
        self.minute = minute
        self.isHomeTeam = isHomeTeam
    }
}

// MARK: - Match
struct Match: Identifiable, Equatable, Codable {
    let id: Int
    let date: Date
    let homeTeamName: String
    let awayTeamName: String
//    let homeTeamLogo: String
//    let awayTeamLogo: String
    let homeScore: Int?
    let awayScore: Int?
    let events: [MatchEvent]
    let matchDetail: MatchDetail?

    init(id: Int, date: Date, homeTeamName: String, awayTeamName: String, homeScore: Int?, awayScore: Int?, events: [MatchEvent] = [], matchDetail: MatchDetail? = nil) {
        self.id = id
        self.date = date
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.events = events
        self.matchDetail = matchDetail
    }
}
