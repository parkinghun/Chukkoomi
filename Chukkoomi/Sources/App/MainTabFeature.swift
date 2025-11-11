//
//  MainTabFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/11/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct MainTabFeature {

    // MARK: - State
    struct State: Equatable {
        var selectedTab: Tab = .home
        var myProfile = MyProfileFeature.State()

        enum Tab: Equatable, CaseIterable {
            case home
            case search
            case post
            case chat
            case profile
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case tabSelected(State.Tab)
        case myProfile(MyProfileFeature.Action)
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.myProfile, action: \.myProfile) {
            MyProfileFeature()
        }

        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .myProfile:
                return .none
            }
        }
    }
}
