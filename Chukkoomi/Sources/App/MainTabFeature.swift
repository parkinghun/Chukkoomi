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
        var home = HomeFeature.State()
        var search = SearchFeature.State()
        // var post = EmptyForVideoFeature.State()
        var postCreate = PostCreateFeature.State()
        var myProfile = MyProfileFeature.State()
        var chatList = ChatListFeature.State()

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
        case home(HomeFeature.Action)
        case search(SearchFeature.Action)
        // case post(EmptyForVideoFeature.Action)
        case postCreate(PostCreateFeature.Action)
        case myProfile(MyProfileFeature.Action)
        case chatList(ChatListFeature.Action)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case logout
        }
    }
    
    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Scope(state: \.search, action: \.search) {
            SearchFeature()
        }

        // Scope(state: \.post, action: \.post) {
        //     EmptyForVideoFeature()
        // }

        Scope(state: \.postCreate, action: \.postCreate) {
            PostCreateFeature()
        }

        Scope(state: \.myProfile, action: \.myProfile) {
            MyProfileFeature()
        }

        Scope(state: \.chatList, action: \.chatList) {
            ChatListFeature()
        }

        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .home, .search, .postCreate, .chatList, .delegate:
                return .none

//            case .post:
//                return .none

            case .myProfile(.logoutCompleted):
                return .send(.delegate(.logout))

            case .myProfile:
                return .none
            }
        }
    }
}
