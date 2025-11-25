//
//  MatchRouter.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/25/25.
//

import Foundation

// MARK: - 기능
enum MatchRouter {
    case fetchMatchDetail(title: String)
}

// MARK: - 정보
extension MatchRouter: Router {
    var version: String {
        return "v1"
    }
    
    var path: String {
        switch self {
        case .fetchMatchDetail:
            return "/\(version)/posts/search"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .fetchMatchDetail:
            return .get
        }
    }
    
    var headers: [HTTPHeader]? {
        return HTTPHeader.basic
    }
    
    var body: AnyEncodable? {
        switch self {
        case .fetchMatchDetail:
            return nil
        }
    }
    
    var bodyEncoder: BodyEncoder? {
        switch self {
        case .fetchMatchDetail:
            return nil
        }
    }
    
    var query: [HTTPQuery]? {
        switch self {
        case .fetchMatchDetail(let title):
            return [
                .custom(key: "title", value: title),
                .category(["match"])
            ]
        }
    }
}
