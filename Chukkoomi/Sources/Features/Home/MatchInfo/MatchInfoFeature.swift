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

        enum TeamType {
            case home
            case away
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case selectTeam(State.TeamType)
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .selectTeam(teamType):
                state.selectedTeam = teamType
                return .none
            }
        }
    }
}
