//
//  MediaRouter.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

// MARK: - 기능
enum MediaRouter {
    case getData(path: String)
}

// MARK: - 정보
extension MediaRouter: Router {
    
    var version: String {
        return "v1"
    }
    
    var path: String {
        switch self {
        case .getData(let path):
            return "/\(version)\(path)"
        }
    }
    
    var method: HTTPMethod {
        .get
    }
    
    var headers: [HTTPHeader]? {
        return HTTPHeader.basic
    }
    
    var body: AnyEncodable? {
        return nil
    }
    
    var bodyEncoder: BodyEncoder? {
        return nil
    }
    
    var query: [HTTPQuery]? {
        return nil
    }
    
}
