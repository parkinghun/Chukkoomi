//
//  MainTabView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/11/25.
//

import SwiftUI
import ComposableArchitecture

struct MainTabView: View {
    let store: StoreOf<MainTabFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TabView(selection: viewStore.binding(
                get: \.selectedTab,
                send: { .tabSelected($0) }
            )) {
                // Home Tab
                NavigationStack {
                    HomeView(
                        store: store.scope(
                            state: \.home,
                            action: \.home
                        )
                    )
                }
                .tabItem {
                    tabIcon(for: .home)
                }
                .tag(MainTabFeature.State.Tab.home)

                // Search Tab
                NavigationStack {
                    SearchView(
                        store: store.scope(
                            state: \.search,
                            action: \.search)
                    )
                }
                .tabItem {
                    tabIcon(for: .search)
                    }
                .tag(MainTabFeature.State.Tab.search)

                // Post Tab
                EmptyForVideoView(
                    store: store.scope(
                        state: \.post,
                        action: \.post
                    )
                )
                .tabItem {
                    tabIcon(for: .post)
                }
                .tag(MainTabFeature.State.Tab.post)

                // Chat Tab
                NavigationStack {
                    ChatListView(
                        store: store.scope(
                            state: \.chatList,
                            action: \.chatList
                        )
                    )
                }
                .tabItem {
                    tabIcon(for: .chat)
                }
                .tag(MainTabFeature.State.Tab.chat)

                // Profile Tab
                NavigationStack {
                    MyProfileView(
                        store: store.scope(
                            state: \.myProfile,
                            action: \.myProfile
                        )
                    )
                }
                .tabItem {
                    tabIcon(for: .profile)
                }
                .tag(MainTabFeature.State.Tab.profile)
            }
        }
    }

    // MARK: - Helper
    @ViewBuilder
    private func tabIcon(for tab: MainTabFeature.State.Tab) -> some View {
        switch tab {
        case .home:
            AppIcon.home
        case .search:
            AppIcon.search
        case .post:
            AppIcon.post
        case .chat:
            AppIcon.chat
        case .profile:
            AppIcon.profile
        }
    }
}
