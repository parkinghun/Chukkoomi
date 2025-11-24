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
                    var hasValidToken = await checkAuthentication()

                    // 토큰은 있는데 userId가 없으면 프로필 조회
                    if hasValidToken, UserDefaultsHelper.userId == nil {
                        do {
                            let profile = try await NetworkManager.shared.performRequest(ProfileRouter.lookupMe, as: ProfileDTO.self).toDomain
                            UserDefaultsHelper.userId = profile.userId
                        } catch {
                            // 프로필 조회 실패 시 로그인 화면으로
                            hasValidToken = false
                        }
                    }

                    await send(.checkAuthenticationResult(hasValidToken))
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
    /// 인증 상태를 확인합니다 (Keychain에 토큰 존재 여부)
    private func checkAuthentication() async -> Bool {
        // Keychain에서 accessToken 확인
        guard let accessToken = KeychainManager.shared.load(for: .accessToken),
              !accessToken.isEmpty else {
            return false
        }

        // refreshToken도 확인
        guard let refreshToken = KeychainManager.shared.load(for: .refreshToken),
              !refreshToken.isEmpty else {
            return false
        }

        // ===== 🧪 Postman 테스트용 AccessToken 출력 =====
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔑 AccessToken (Postman 테스트용)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Authorization: \(accessToken)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        return true
    }
}
