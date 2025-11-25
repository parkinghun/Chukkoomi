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
    let playerName: String
    let minute: Int
    let teamName: String // 홈팀 or 원정팀

    init(id: UUID = UUID(), type: MatchEventType, playerName: String, minute: Int, teamName: String) {
        self.id = id
        self.type = type
        self.playerName = playerName
        self.minute = minute
        self.teamName = teamName
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

    init(id: Int, date: Date, homeTeamName: String, awayTeamName: String, homeScore: Int?, awayScore: Int?, events: [MatchEvent] = []) {
        self.id = id
        self.date = date
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.events = events
    }
}
