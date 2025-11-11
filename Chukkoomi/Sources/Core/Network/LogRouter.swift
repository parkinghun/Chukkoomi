//
//  LogRouter.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

// MARK: - 기능
enum LogRouter {
    case getLogs // 서버 로그 조회
}

// MARK: - 정보
extension LogRouter: Router {

    var version: String {
        return "v1"
    }

    var path: String {
        switch self {
        case .getLogs:
            return "/\(version)/logs"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getLogs:
            return .get
        }
    }

    var headers: [HTTPHeader]? {
        switch self {
        case .getLogs:
            return [.apiKey]
        }
    }

    var body: AnyEncodable? {
        switch self {
        case .getLogs:
            return nil
        }
    }

    var bodyEncoder: BodyEncoder? {
        switch self {
        case .getLogs:
            return nil
        }
    }

    var query: [HTTPQuery]? {
        switch self {
        case .getLogs:
            return nil
        }
    }
}
