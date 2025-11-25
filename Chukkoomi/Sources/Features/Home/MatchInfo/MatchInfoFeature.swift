//
//  MatchInfoFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/24/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct MatchInfoFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        let match: Match
        var selectedTeam: TeamType = .home
        var matchDetail: MatchDetail?
        var isLoading: Bool = false

        enum TeamType {
            case home
            case away
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case selectTeam(State.TeamType)
        case fetchMatchDetail
        case fetchMatchDetailResponse(Result<MatchDetail, Error>)

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.fetchMatchDetail, .fetchMatchDetail):
                return true
            case let (.selectTeam(lhsType), .selectTeam(rhsType)):
                return lhsType == rhsType
            case (.fetchMatchDetailResponse, .fetchMatchDetailResponse):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.fetchMatchDetail)

            case let .selectTeam(teamType):
                state.selectedTeam = teamType
                return .none

            case .fetchMatchDetail:
                state.isLoading = true
                return .run { send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            MatchRouter.fetchMatchDetail(title: "1138378"),
                            as: MatchDetailListDTO.self
                        )

                        let matchDetail = try response.toDomain
                        await send(.fetchMatchDetailResponse(.success(matchDetail)))
                    } catch {
                        print("Match Detail 받아오기 실패: \(error)")
                        await send(.fetchMatchDetailResponse(.failure(error)))
                    }
                }

            case let .fetchMatchDetailResponse(.success(matchDetail)):
                state.isLoading = false
                state.matchDetail = matchDetail
                return .none

            case let .fetchMatchDetailResponse(.failure(error)):
                state.isLoading = false
                print("Error: \(error.localizedDescription)")
                return .none
            }
        }
    }
}
