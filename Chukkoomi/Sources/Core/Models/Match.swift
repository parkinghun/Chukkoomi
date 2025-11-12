//
//  Match.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/11/25.
//

import Foundation

struct Match: Identifiable, Equatable, Codable {
    let id: Int
    let date: Date
    let homeTeamName: String
    let awayTeamName: String
//    let homeTeamLogo: String
//    let awayTeamLogo: String
    let homeScore: Int?
    let awayScore: Int?
}
