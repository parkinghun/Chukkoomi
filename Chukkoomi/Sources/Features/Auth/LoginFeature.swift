//
//  LoginFeature.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import ComposableArchitecture
import Foundation

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
}

extension NetworkClient: DependencyKey {
    static let liveValue = NetworkClient(
        signInWithEmail: { email, password in
            let router = UserRouter.signInWithEmail(email: email, password: password)
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
