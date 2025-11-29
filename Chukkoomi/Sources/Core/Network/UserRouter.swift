//
//  UserRouter.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

// MARK: - 기능
enum UserRouter {
    case validateEmail(email: String) // 이메일 중복 체크
    case signUp(email: String, password: String, nickname: String) // 회원가입
    case signInWithEmail(email: String, password: String) // 이메일 로그인
    case signInWithKakao(oauthToken: String) // 카카오 로그인
    case signInWithApple(idToken: String) // 애플 로그인
    case withdraw // 회원 탈퇴
    case search(nickname: String) //유저 검색
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
        case .signUp:
            return "/\(version)/users/join"
        case .signInWithEmail:
            return "/\(version)/users/login"
        case .signInWithKakao:
            return "/\(version)/users/login/kakao"
        case .signInWithApple:
            return "/\(version)/users/login/apple"
        case .withdraw:
            return "/\(version)/users/withdraw"
        case .search:
            return "/\(version)/users/search"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .validateEmail, .signUp, .signInWithEmail, .signInWithKakao, .signInWithApple:
            return .post
        case .withdraw, .search:
            return .get
        }
    }
    
    var headers: [HTTPHeader]? {
        switch self {
        case .validateEmail:
            return [.apiKey]
        case .signUp, .signInWithEmail, .signInWithKakao, .signInWithApple:
            return [.apiKey, .productId]
        case .withdraw, .search:
            return HTTPHeader.basic
        }
    }
    
    var body: AnyEncodable? {
        switch self {
        case .validateEmail(let email):
            return .init(EmailValidationBody(email: email))
        case .signUp(let email, let password, let nickname):
            return .init(SignUpBody(email: email, password: password, nickname: nickname))
        case .signInWithEmail(let email, let password):
            return .init(SignInWithEmailBody(email: email, password: password))
        case .signInWithKakao(let oauthToken):
            return .init(SignInWithKakaoBody(oauthToken: oauthToken))
        case .signInWithApple(let idToken):
            return .init(SignInWithAppleBody(idToken: idToken))
        case .withdraw, .search:
            return nil
        }
    }
    
    var bodyEncoder: BodyEncoder? {
        switch self {
        case .validateEmail, .signUp, .signInWithEmail, .signInWithKakao, .signInWithApple:
            return .json
        case .withdraw, .search:
            return nil
        }
    }
    
    var query: [HTTPQuery]? {
        switch self {
        case .validateEmail, .signUp, .signInWithEmail, .signInWithKakao, .signInWithApple, .withdraw:
            return nil
        case .search(let nickname):
            return [.custom(key: "nick", value: nickname)]
        }
    }
    
}

// MARK: - Body 객체
extension UserRouter {
    
    private struct EmailValidationBody: Encodable {
        let email: String
    }
    
    private struct SignUpBody: Encodable {
        let email: String
        let password: String
        let nickname: String
        
        enum CodingKeys: String, CodingKey {
            case email
            case password
            case nickname = "nick"
        }
        
        func encode(to encoder: any Encoder) throws {
            var container: KeyedEncodingContainer<UserRouter.SignUpBody.CodingKeys> = encoder.container(keyedBy: UserRouter.SignUpBody.CodingKeys.self)
            try container.encode(self.email, forKey: UserRouter.SignUpBody.CodingKeys.email)
            try container.encode(self.password, forKey: UserRouter.SignUpBody.CodingKeys.password)
            try container.encode(self.nickname, forKey: UserRouter.SignUpBody.CodingKeys.nickname)
        }
    }
    
    private struct SignInWithEmailBody: Encodable {
        let email: String
        let password: String
    }
    
    private struct SignInWithKakaoBody: Encodable {
        let oauthToken: String
    }
    
    private struct SignInWithAppleBody: Encodable {
        let idToken: String
    }
}
