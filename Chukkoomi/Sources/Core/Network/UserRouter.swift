//
//  UserRouter.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

// MARK: - 기능
enum UserRouter {
    case validateEmail(String)
}

// MARK: - 정보
extension UserRouter: Router {
    
    var version: String {
        return "v1"
    }
    
    var path: String {
        switch self {
        case .validateEmail:
            return "/\(version)/users/validation/email"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .validateEmail:
            return .post
        }
    }
    
    var headers: [HTTPHeader]? {
        switch self {
        case .validateEmail:
            return [.apiKey]
        }
    }
    
    var body: AnyEncodable? {
        switch self {
        case .validateEmail(let email):
            return .init(EmailValidationBody(email: email))
        }
    }
    
    var bodyEncoder: BodyEncoder {
        switch self {
        case .validateEmail:
            return .json
        }
    }
    
    var query: [HTTPQuery]? {
        switch self {
        case .validateEmail:
            return nil
        }
    }
    
}

// MARK: - Body 객체
extension UserRouter {
    struct EmailValidationBody: Encodable {
        let email: String
    }
}
