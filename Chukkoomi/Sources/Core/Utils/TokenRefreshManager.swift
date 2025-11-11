//
//  TokenRefreshManager.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import Foundation

actor TokenRefreshManager {

    static let shared = TokenRefreshManager()

    private init() {}

    // 현재 토큰 갱신 중인지 여부
    private var isRefreshing = false

    // 갱신 대기 중인 Continuation들
    private var waitingContinuations: [CheckedContinuation<Bool, Never>] = []

    // MARK: - 토큰 갱신
    /// 토큰 갱신을 시도합니다. 이미 갱신 중이면 대기합니다.
    /// - Returns: 갱신 성공 여부
    func refreshTokenIfNeeded() async -> Bool {
        // 이미 갱신 중이면 대기
        if isRefreshing {
            return await withCheckedContinuation { continuation in
                waitingContinuations.append(continuation)
            }
        }

        // 갱신 시작
        isRefreshing = true

        // 실제 갱신 수행
        let success = await performTokenRefresh()

        // 갱신 완료 - 대기 중인 continuation들에게 알림
        isRefreshing = false
        let continuations = waitingContinuations
        waitingContinuations.removeAll()

        for continuation in continuations {
            continuation.resume(returning: success)
        }

        return success
    }

    // MARK: - 실제 토큰 갱신 수행
    private func performTokenRefresh() async -> Bool {
        // Keychain에서 RefreshToken 가져오기
        guard let refreshToken = KeychainManager.shared.load(for: .refreshToken) else {
            await handleLogout()
            return false
        }

        do {
            // Refresh API 호출
            let router = AuthRouter.refresh(refreshToken: refreshToken)
            let response = try await NetworkManager.shared.performRequestWithoutInterception(
                router,
                as: RefreshTokenResponseDTO.self
            )

            // 새 토큰 저장
            let authToken = response.toDomain
            KeychainManager.shared.save(authToken.accessToken, for: .accessToken)
            KeychainManager.shared.save(authToken.refreshToken, for: .refreshToken)

            return true

        } catch {
            await handleLogout()
            return false
        }
    }

    // MARK: - 로그아웃 처리
    private func handleLogout() async {
        // Keychain 토큰 삭제
        KeychainManager.shared.deleteAll()

        // 메인 스레드에서 로그아웃 처리
        await MainActor.run {
            // TODO: 로그아웃 상태로 전환 (예: 로그인 화면으로 이동)
            NotificationCenter.default.post(name: .userDidLogout, object: nil)
        }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
}
