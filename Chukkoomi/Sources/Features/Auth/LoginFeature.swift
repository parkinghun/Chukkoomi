//
//  LoginFeature.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import ComposableArchitecture
import Foundation
import KakaoSDKAuth
import KakaoSDKUser
import AuthenticationServices

@Reducer
struct LoginFeature {

    // MARK: - State
    struct State: Equatable {
        var email: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String?
        var isLoginSuccessful: Bool = false
    }

    // MARK: - Action
    enum Action {
        case emailChanged(String)
        case passwordChanged(String)
        case loginButtonTapped
        case loginResponse(Result<SignResponse, Error>)
        case kakaoLoginButtonTapped
        case kakaoLoginResponse(Result<SignResponse, Error>)
        case appleLoginButtonTapped
        case appleLoginResponse(Result<SignResponse, Error>)
        case clearFields // 필드 초기화
    }

    // MARK: - Dependency
    @Dependency(\.networkClient) var networkClient

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .emailChanged(email):
                state.email = email
                state.errorMessage = nil
                return .none

            case let .passwordChanged(password):
                state.password = password
                state.errorMessage = nil
                return .none

            case .loginButtonTapped:
                // 유효성 검사
                guard !state.email.isEmpty, !state.password.isEmpty else {
                    state.errorMessage = "이메일과 비밀번호를 입력해주세요."
                    return .none
                }

                // 이메일 형식 검사
                guard state.email.contains("@") else {
                    state.errorMessage = "올바른 이메일 형식이 아닙니다."
                    return .none
                }

                guard state.email.lowercased().contains(".com") else {
                    state.errorMessage = "올바른 이메일 형식이 아닙니다."
                    return .none
                }

                // 비밀번호 길이 검사
                guard state.password.count >= 8 else {
                    state.errorMessage = "비밀번호는 8자 이상이어야 합니다."
                    return .none
                }

                state.isLoading = true
                state.errorMessage = nil

                // 로그인 API 호출
                return .run { [email = state.email, password = state.password] send in
                    await send(.loginResponse(
                        Result {
                            try await networkClient.signInWithEmail(email, password)
                        }
                    ))
                }

            case let .loginResponse(.success(response)):
                state.isLoading = false

                // Keychain에 토큰 저장
                KeychainManager.shared.save(response.accessToken, for: .accessToken)
                KeychainManager.shared.save(response.refreshToken, for: .refreshToken)
                
                // UserDefaults에 userId 저장
                UserDefaultsHelper.userId = response.userId

                state.isLoginSuccessful = true
                return .none

            case let .loginResponse(.failure(error)):
                state.isLoading = false

                // 서버 에러 메시지 또는 기본 메시지 표시
                if let networkError = error as? NetworkError {
                    state.errorMessage = networkError.errorDescription ?? "로그인에 실패했습니다. 다시 시도해주세요."
                } else {
                    state.errorMessage = "로그인에 실패했습니다. 다시 시도해주세요."
                }

                return .none

            case .kakaoLoginButtonTapped:
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await send(.kakaoLoginResponse(
                        Result {
                            try await networkClient.signInWithKakao()
                        }
                    ))
                }

            case let .kakaoLoginResponse(.success(response)):
                state.isLoading = false

                // Keychain에 토큰 저장
                KeychainManager.shared.save(response.accessToken, for: .accessToken)
                KeychainManager.shared.save(response.refreshToken, for: .refreshToken)

                // UserDefaults에 userId 저장
                UserDefaultsHelper.userId = response.userId

                state.isLoginSuccessful = true
                return .none

            case let .kakaoLoginResponse(.failure(error)):
                state.isLoading = false

                // 에러 메시지 표시
                if let networkError = error as? NetworkError {
                    state.errorMessage = networkError.errorDescription ?? "카카오 로그인에 실패했습니다."
                } else {
                    state.errorMessage = "카카오 로그인에 실패했습니다."
                }

                return .none

            case .appleLoginButtonTapped:
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await send(.appleLoginResponse(
                        Result {
                            try await networkClient.signInWithApple()
                        }
                    ))
                }

            case let .appleLoginResponse(.success(response)):
                state.isLoading = false

                // Keychain에 토큰 저장
                KeychainManager.shared.save(response.accessToken, for: .accessToken)
                KeychainManager.shared.save(response.refreshToken, for: .refreshToken)

                // UserDefaults에 userId 저장
                UserDefaultsHelper.userId = response.userId

                state.isLoginSuccessful = true
                return .none

            case let .appleLoginResponse(.failure(error)):
                state.isLoading = false

                // 에러 메시지 표시
                if let networkError = error as? NetworkError {
                    state.errorMessage = networkError.errorDescription ?? "Apple 로그인에 실패했습니다."
                } else {
                    state.errorMessage = "Apple 로그인에 실패했습니다."
                }

                return .none

            case .clearFields:
                state.email = ""
                state.password = ""
                state.errorMessage = nil
                state.isLoading = false
                return .none
            }
        }
    }
}

// MARK: - NetworkClient Dependency
struct NetworkClient {
    var signInWithEmail: @Sendable (String, String) async throws -> SignResponse
    var signInWithKakao: @Sendable () async throws -> SignResponse
    var signInWithApple: @Sendable () async throws -> SignResponse
}

extension NetworkClient: DependencyKey {
    static let liveValue = NetworkClient(
        signInWithEmail: { email, password in
            let router = UserRouter.signInWithEmail(email: email, password: password)
            let responseDTO = try await NetworkManager.shared.performRequest(router, as: SignResponseDTO.self)
            return responseDTO.toDomain
        },
        signInWithKakao: {
            // Kakao SDK를 사용하여 로그인
            let oauthToken = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                if UserApi.isKakaoTalkLoginAvailable() {
                    // 카카오톡 앱으로 로그인
                    UserApi.shared.loginWithKakaoTalk { oauthToken, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let oauthToken = oauthToken {
                            continuation.resume(returning: oauthToken.accessToken)
                        }
                    }
                } else {
                    // 카카오 계정으로 로그인 (웹)
                    UserApi.shared.loginWithKakaoAccount { oauthToken, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let oauthToken = oauthToken {
                            continuation.resume(returning: oauthToken.accessToken)
                        }
                    }
                }
            }

            // 서버에 OAuth 토큰 전송
            let router = UserRouter.signInWithKakao(oauthToken: oauthToken)
            let responseDTO = try await NetworkManager.shared.performRequest(router, as: SignResponseDTO.self)
            return responseDTO.toDomain
        },
        signInWithApple: {
            // Apple Sign In 처리
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])

            // Delegate를 통해 결과 받기
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
                let delegate = AppleSignInDelegate(continuation: continuation)
                authorizationController.delegate = delegate
                authorizationController.presentationContextProvider = delegate
                authorizationController.performRequests()

                // delegate를 메모리에 유지
                objc_setAssociatedObject(authorizationController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            }

            guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                throw NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple ID 토큰을 가져올 수 없습니다."])
            }

            // 서버에 Identity Token 전송
            let router = UserRouter.signInWithApple(idToken: identityToken)
            let responseDTO = try await NetworkManager.shared.performRequest(router, as: SignResponseDTO.self)
            return responseDTO.toDomain
        }
    )
}

extension DependencyValues {
    var networkClient: NetworkClient {
        get { self[NetworkClient.self] }
        set { self[NetworkClient.self] = newValue }
    }
}

// MARK: - Apple Sign In Delegate
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
