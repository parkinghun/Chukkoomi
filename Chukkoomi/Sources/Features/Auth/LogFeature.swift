//
//  LogFeature.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct LogFeature {

    // MARK: - State
    struct State: Equatable {
        var logs: [LogItem] = []
        var isLoading: Bool = false
        var errorMessage: String?
    }

    // MARK: - Action
    enum Action {
        case fetchLogsButtonTapped
        case logsResponse(Result<LogResponse, Error>)
    }

    // MARK: - Dependency
    @Dependency(\.logClient) var logClient

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fetchLogsButtonTapped:
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await send(.logsResponse(
                        Result {
                            try await logClient.fetchLogs()
                        }
                    ))
                }

            case let .logsResponse(.success(response)):
                state.isLoading = false
                state.logs = response.logs
                return .none

            case let .logsResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = "로그 조회 실패: \(error.localizedDescription)"
                return .none
            }
        }
    }
}

// MARK: - LogClient Dependency
struct LogClient {
    var fetchLogs: @Sendable () async throws -> LogResponse
}

extension LogClient: DependencyKey {
    static let liveValue = LogClient(
        fetchLogs: {
            let router = LogRouter.getLogs
            let responseDTO = try await NetworkManager.shared.performRequest(router, as: LogResponseDTO.self)
            return responseDTO.toDomain
        }
    )
}

extension DependencyValues {
    var logClient: LogClient {
        get { self[LogClient.self] }
        set { self[LogClient.self] = newValue }
    }
}
