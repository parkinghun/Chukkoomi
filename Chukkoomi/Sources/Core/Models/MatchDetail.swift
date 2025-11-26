//
//  MatchDetail.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/25/25.
//

import Foundation

struct MatchDetail: Equatable, Codable {
    let id: String
    let homeTeamName: String
    let awayTeamName: String
    let matchDate: Date
    let homeKeeper: Player
    let homeDefends: [Player]
    let homeMidFields: [Player]
    let homeForwards: [Player]
    let awayKeeper: Player
    let awayDefends: [Player]
    let awayMidFields: [Player]
    let awayForwards: [Player]
    let homeUniform: String
    let awayUniform: String
}

struct Player: Equatable, Codable {
    let id: String
    let number: Int
    let name: String
}
