//
//  FootballRouter.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/11/25.
//

import Foundation

// MARK: - 기능
enum FootballRouter {
    case fixtures(league: Int, season: Int)  // 경기 결과 조회
}

// MARK: - 정보
extension FootballRouter: Router {
    
    var version: String {
        return ""
    }
    
    var baseURL: String {
        return "https://v3.football.api-sports.io"
    }
    
    var path: String {
        switch self {
        case .fixtures:
            return "/fixtures"
        }
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var headers: [HTTPHeader]? {
        return [.custom(key: "x-apisports-key", value: APIInfo.footballAPIKey)]
    }
    
    var body: AnyEncodable? {
        return nil
    }
    
    var bodyEncoder: BodyEncoder? {
        return nil
    }
    
    var query: [HTTPQuery]? {
        switch self {
        case .fixtures(let league, let season):
            return [
                .custom(key: "league", value: "\(league)"),
                .custom(key: "season", value: "\(season)")
            ]
        }
    }
    
}
