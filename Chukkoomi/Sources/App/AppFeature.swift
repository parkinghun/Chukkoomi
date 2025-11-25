//
//  AppFeature.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/12/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var isLoggedIn: Bool = false
        var isCheckingAuth: Bool = true

        // Child Features
        var loginState: LoginFeature.State?
        var mainTabState: MainTabFeature.State?
    }

    // MARK: - Action
    enum Action {
        case onAppear
        case checkAuthenticationResult(Bool)
        case login(LoginFeature.Action)
        case mainTab(MainTabFeature.Action)
        case logout
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 앱 시작 시 인증 상태 체크
                return .run { send in
                    do {
                        let hasValidToken = try await checkAuthentication()
                        await send(.checkAuthenticationResult(hasValidToken))
                    } catch NetworkError.refreshTokenExpired {
                        // RefreshToken 만료 - 로그아웃 처리
                        await send(.logout)
                    } catch {
                        // 기타 에러 - 로그인 화면으로
                        await send(.checkAuthenticationResult(false))
                    }
                }

            case let .checkAuthenticationResult(isAuthenticated):
                state.isCheckingAuth = false
                state.isLoggedIn = isAuthenticated

                if isAuthenticated {
                    // 로그인 상태 - MainTabView 표시
                    state.mainTabState = MainTabFeature.State()
                    state.loginState = nil
                } else {
                    // 비로그인 상태 - LoginView 표시
                    state.loginState = LoginFeature.State()
                    state.mainTabState = nil
                }

                return .none

            case .login(.loginResponse(.success)), .login(.kakaoLoginResponse(.success)), .login(.appleLoginResponse(.success)):
                // 로그인 성공 (이메일/카카오/애플) - MainTabView로 전환
                state.isLoggedIn = true
                state.mainTabState = MainTabFeature.State()
                state.loginState = nil
                return .none

            case .login:
                return .none

            case .mainTab(.delegate(.logout)):
                return .send(.logout)

            case .mainTab:
                return .none

            case .logout:
                // 아직 state를 변경하지 않음 - child reducer가 먼저 처리하도록
                return .none
            }
        }
        .ifLet(\.loginState, action: \.login) {
            LoginFeature()
        }
        .ifLet(\.mainTabState, action: \.mainTab) {
            MainTabFeature()
        }

        // child reducer 이후에 실행되는 parent reducer
        Reduce { state, action in
            switch action {
            case .logout:
                // 로그아웃 - LoginView로 전환
                state.isLoggedIn = false
                state.loginState = LoginFeature.State()
                state.mainTabState = nil

                // Keychain 토큰 삭제
                KeychainManager.shared.deleteAll()

                // UserDefaults userId 삭제
                UserDefaultsHelper.userId = nil

                return .none

            default:
                return .none
            }
        }
    }

    // MARK: - Helper Methods
    /// 인증 상태를 확인합니다 (실제 API 호출로 토큰 유효성 검증)
    private func checkAuthentication() async throws -> Bool {
        // 1. Keychain에서 토큰 확인
        guard let accessToken = KeychainManager.shared.load(for: .accessToken),
              !accessToken.isEmpty else {
            return false
        }

        guard let refreshToken = KeychainManager.shared.load(for: .refreshToken),
              !refreshToken.isEmpty else {
            return false
        }

        // 2. 실제 API 호출로 토큰 유효성 검증 (프로필 조회)
        do {
            let profile = try await NetworkManager.shared.performRequest(
                ProfileRouter.lookupMe,
                as: ProfileDTO.self
            ).toDomain

            // 프로필 조회 성공 - userId 저장
            UserDefaultsHelper.userId = profile.userId
            return true

        } catch NetworkError.refreshTokenExpired {
            // RefreshToken 만료 (418) - 에러를 상위로 전파하여 로그아웃 처리
            throw NetworkError.refreshTokenExpired

        } catch NetworkError.unauthorized {
            // 토큰 갱신 실패 - 로그인 필요
            return false

        } catch {
            // 기타 에러 (네트워크 에러 등) - 일단 로그인 상태로 간주
            // 실제 API 호출 시 다시 검증됨
            return true
        }
    }
}
