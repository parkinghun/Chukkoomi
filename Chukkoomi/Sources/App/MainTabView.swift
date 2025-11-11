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
                ContentView()
                    .tabItem {
                        tabIcon(
                            for: .home,
                            isSelected: viewStore.selectedTab == .home
                        )
                    }
                    .tag(MainTabFeature.State.Tab.home)

                // Search Tab
                ContentView()
                    .tabItem {
                        tabIcon(
                            for: .search,
                            isSelected: viewStore.selectedTab == .search
                        )
                    }
                    .tag(MainTabFeature.State.Tab.search)

                // Post Tab
                ContentView()
                    .tabItem {
                        tabIcon(
                            for: .post,
                            isSelected: viewStore.selectedTab == .post
                        )
                    }
                    .tag(MainTabFeature.State.Tab.post)

                // Chat Tab
                ContentView()
                    .tabItem {
                        tabIcon(
                            for: .chat,
                            isSelected: viewStore.selectedTab == .chat
                        )
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
                    tabIcon(
                        for: .profile,
                        isSelected: viewStore.selectedTab == .profile
                    )
                }
                .tag(MainTabFeature.State.Tab.profile)
            }
        }
    }

    // MARK: - Helper
    @ViewBuilder
    private func tabIcon(for tab: MainTabFeature.State.Tab, isSelected: Bool) -> some View {
        switch tab {
        case .home:
            isSelected ? AppIcon.homeFill : AppIcon.home
        case .search:
            AppIcon.search
        case .post:
            AppIcon.post
        case .chat:
            isSelected ? AppIcon.chatFill : AppIcon.chat
        case .profile:
            isSelected ? AppIcon.personFill : AppIcon.person
        }
    }
}
