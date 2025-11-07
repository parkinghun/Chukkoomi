//
//  FollowRouter.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

// MARK: - 기능
enum FollowRouter {
    case follow(id: String, follow: Bool) // 팔로우/언팔로우
}

// MARK: - 정보
extension FollowRouter: Router {
    
    var version: String {
        return "v1"
    }
    
    var path: String {
        switch self {
        case .follow(let id, _):
            return "/\(version)/follow/\(id)"
        }
    }
    
    var method: HTTPMethod {
        return .post
    }
    
    var headers: [HTTPHeader]? {
        return HTTPHeader.basic
    }
    
    var body: AnyEncodable? {
        switch self {
        case .follow(_, let follow):
            return .init(FollowRequestBody(followStatus: follow))
        }
    }
    
    var bodyEncoder: BodyEncoder? {
        return .json
    }
    
    var query: [HTTPQuery]? {
        return nil
    }
    
}

// MARK: - Body 객체
extension FollowRouter {
    
    private struct FollowRequestBody: Encodable {
        let followStatus: Bool
        
        enum CodingKeys: String, CodingKey {
            case followStatus = "follow_status"
        }
        
        func encode(to encoder: any Encoder) throws {
            var container: KeyedEncodingContainer<FollowRouter.FollowRequestBody.CodingKeys> = encoder.container(keyedBy: FollowRouter.FollowRequestBody.CodingKeys.self)
            try container.encode(self.followStatus, forKey: FollowRouter.FollowRequestBody.CodingKeys.followStatus)
        }
    }
    
}
