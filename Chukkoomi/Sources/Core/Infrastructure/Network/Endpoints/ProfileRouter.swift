//
//  ProfileRouter.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

// MARK: - 기능
enum ProfileRouter {
    case updateMe(profile: EditProfileRequestBody) // 내 프로필 수정
    case lookupMe // 내 프로필 조회
    case lookupOther(id: String) // 다른 사람 프로필 조회
}

// MARK: - 정보
extension ProfileRouter: Router {
    
    var version: String {
        return "v1"
    }
    
    var path: String {
        switch self {
        case .updateMe, .lookupMe:
            return "/\(version)/users/me/profile"
        case .lookupOther(let id):
            return "/\(version)/users/\(id)/profile"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .updateMe:
            return .put
        case .lookupMe, .lookupOther:
            return .get
        }
    }
    
    var headers: [HTTPHeader]? {
        return HTTPHeader.basic
    }
    
    var body: AnyEncodable? {
        switch self {
        case .updateMe(let profile):
            return .init(profile)
        case .lookupMe, .lookupOther:
            return nil
        }
    }
    
    var bodyEncoder: BodyEncoder? {
        switch self {
        case .updateMe:
            return .multipart
        case .lookupMe, .lookupOther:
            return nil
        }
    }
    
    var query: [HTTPQuery]? {
        return nil
    }
    
}

// MARK: - Body 객체
extension ProfileRouter {

    struct EditProfileRequestBody: Encodable {
        let nick: String?
        let profile: MultipartFile?
        let info1: String?

        init(nickname: String? = nil, profileImage: MultipartFile? = nil, introduce: String? = nil) {
            self.nick = nickname
            self.profile = profileImage
            self.info1 = introduce
        }

        func encode(to encoder: Encoder) throws {
            // MultipartFormDataEncoder는 Mirror를 사용하므로 이 메서드는 호출되지 않음
            // AnyEncodable의 제네릭 제약(<T: Encodable>)을 만족시키기 위해서만 필요
        }
    }

}
