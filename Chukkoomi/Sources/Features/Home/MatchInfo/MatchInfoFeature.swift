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

        init(match: Match) {
            self.match = match
            self.matchDetail = match.matchDetail
        }

        enum TeamType {
            case home
            case away
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case selectTeam(State.TeamType)

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear):
                return true
            case let (.selectTeam(lhsType), .selectTeam(rhsType)):
                return lhsType == rhsType
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
                return .none

            case let .selectTeam(teamType):
                state.selectedTeam = teamType
                return .none
            }
        }
    }
}
