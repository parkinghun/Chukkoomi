//
//  AuthRouter.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

// MARK: - 기능
enum AuthRouter {
    case refresh(refreshToken: String) // 리프레시 토큰 갱신
}

// MARK: - 정보
extension AuthRouter: Router {

    var version: String {
        return "v1"
    }

    var path: String {
        switch self {
        case .refresh:
            return "/\(version)/auth/refresh"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .refresh:
            return .get
        }
    }

    var headers: [HTTPHeader]? {
        switch self {
        case .refresh(let refreshToken):
            return [
                .apiKey,
                .custom(key: "Authorization", value: refreshToken),
                .productId
            ]
        }
    }

    var body: AnyEncodable? {
        switch self {
        case .refresh:
            return nil
        }
    }

    var bodyEncoder: BodyEncoder? {
        switch self {
        case .refresh:
            return nil
        }
    }

    var query: [HTTPQuery]? {
        switch self {
        case .refresh:
            return nil
        }
    }
}
