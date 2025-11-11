//
//  SignUpFeature.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SignUpFeature {

    // MARK: - State
    struct State: Equatable {
        var email: String = ""
        var password: String = ""
        var passwordConfirm: String = ""
        var nickname: String = ""
        var isLoading: Bool = false
        var errorMessage: String?
        var isEmailValid: Bool? = nil // nil: 미확인, true: 사용가능, false: 중복
        var validatedEmail: String = "" // 중복확인한 이메일 저장
        var isSignUpSuccessful: Bool = false
    }

    // MARK: - Action
    enum Action {
        case emailChanged(String)
        case passwordChanged(String)
        case passwordConfirmChanged(String)
        case nicknameChanged(String)
        case checkEmailButtonTapped
        case emailValidationResponse(Result<Void, Error>)
        case signUpButtonTapped
        case signUpResponse(Result<SignResponse, Error>)
        case clearFields // 필드 초기화
    }

    // MARK: - Dependency
    @Dependency(\.signUpClient) var signUpClient

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .emailChanged(email):
                state.email = email
                // 중복확인한 이메일과 다르면 중복체크 초기화
                if email != state.validatedEmail {
                    state.isEmailValid = nil
                }
                state.errorMessage = nil
                return .none

            case let .passwordChanged(password):
                state.password = password
                state.errorMessage = nil
                return .none

            case let .passwordConfirmChanged(passwordConfirm):
                state.passwordConfirm = passwordConfirm
                state.errorMessage = nil
                return .none

            case let .nicknameChanged(nickname):
                state.nickname = nickname
                state.errorMessage = nil
                return .none

            case .checkEmailButtonTapped:
                // 이메일 유효성 검사
                guard !state.email.isEmpty else {
                    state.errorMessage = "이메일을 입력해주세요."
                    return .none
                }

                // 이메일 형식 검사 (@와 .com 포함)
                guard state.email.contains("@") else {
                    state.errorMessage = "올바른 이메일 형식이 아닙니다."
                    return .none
                }

                guard state.email.lowercased().contains(".com") else {
                    state.errorMessage = "올바른 이메일 형식이 아닙니다."
                    return .none
                }

                state.isLoading = true
                state.errorMessage = nil

                // 이메일 중복 체크 API 호출
                return .run { [email = state.email] send in
                    await send(.emailValidationResponse(
                        Result {
                            try await signUpClient.validateEmail(email)
                        }
                    ))
                }

            case .emailValidationResponse(.success):
                state.isLoading = false
                state.isEmailValid = true
                state.validatedEmail = state.email // 중복확인한 이메일 저장
                return .none

            case let .emailValidationResponse(.failure(error)):
                state.isLoading = false
                state.isEmailValid = false

                // 서버 에러 메시지 또는 기본 메시지 표시
                if let networkError = error as? NetworkError {
                    state.errorMessage = networkError.errorDescription ?? "이메일 확인에 실패했습니다."
                } else {
                    state.errorMessage = "이메일 확인에 실패했습니다."
                }
                return .none

            case .signUpButtonTapped:
                // 유효성 검사
                guard !state.email.isEmpty, !state.password.isEmpty, !state.passwordConfirm.isEmpty, !state.nickname.isEmpty else {
                    state.errorMessage = "모든 항목을 입력해주세요."
                    return .none
                }

                guard state.isEmailValid == true && state.email == state.validatedEmail else {
                    state.errorMessage = "이메일 중복 확인을 해주세요."
                    return .none
                }

                guard state.password.count >= 8 else {
                    state.errorMessage = "비밀번호는 8자 이상이어야 합니다."
                    return .none
                }

                guard state.password == state.passwordConfirm else {
                    state.errorMessage = "비밀번호가 일치하지 않습니다."
                    return .none
                }

                state.isLoading = true
                state.errorMessage = nil

                // 회원가입 API 호출
                return .run { [email = state.email, password = state.password, nickname = state.nickname] send in
                    await send(.signUpResponse(
                        Result {
                            try await signUpClient.signUp(email, password, nickname)
                        }
                    ))
                }

            case let .signUpResponse(.success(response)):
                state.isLoading = false

                // Keychain에 토큰 저장
                KeychainManager.shared.save(response.accessToken, for: .accessToken)
                KeychainManager.shared.save(response.refreshToken, for: .refreshToken)

                state.isSignUpSuccessful = true
                return .none

            case let .signUpResponse(.failure(error)):
                state.isLoading = false

                // 서버 에러 메시지 또는 기본 메시지 표시
                if let networkError = error as? NetworkError {
                    state.errorMessage = networkError.errorDescription ?? "회원가입에 실패했습니다. 다시 시도해주세요."
                } else {
                    state.errorMessage = "회원가입에 실패했습니다. 다시 시도해주세요."
                }

                return .none

            case .clearFields:
                state.email = ""
                state.password = ""
                state.passwordConfirm = ""
                state.nickname = ""
                state.errorMessage = nil
                state.isEmailValid = nil
                state.validatedEmail = ""
                state.isLoading = false
                return .none
            }
        }
    }
}

// MARK: - SignUpClient Dependency
struct SignUpClient {
    var validateEmail: @Sendable (String) async throws -> Void
    var signUp: @Sendable (String, String, String) async throws -> SignResponse
}

extension SignUpClient: DependencyKey {
    static let liveValue = SignUpClient(
        validateEmail: { email in
            let router = UserRouter.validateEmail(email: email)
            // 이메일 중복 체크는 401 인터셉트 없이 호출
            _ = try await NetworkManager.shared.performRequestWithoutInterception(router, as: BasicMessageResponseDTO.self)
        },
        signUp: { email, password, nickname in
            let router = UserRouter.signUp(email: email, password: password, nickname: nickname)
            // 회원가입은 401 인터셉트 없이 호출
            let responseDTO = try await NetworkManager.shared.performRequestWithoutInterception(router, as: SignResponseDTO.self)
            return responseDTO.toDomain
        }
    )
}

extension DependencyValues {
    var signUpClient: SignUpClient {
        get { self[SignUpClient.self] }
        set { self[SignUpClient.self] = newValue }
    }
}
