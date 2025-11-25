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

    init(store: StoreOf<MainTabFeature>) {
        self.store = store
        configureTabBarAppearance()
    }

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
                NavigationStack {
                    PostCreateView(
                        store: store.scope(
                            state: \.postCreate,
                            action: \.postCreate
                        )
                    )
                }
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
            .onAppear {
                // 뷰가 나타날 때 실제 UITabBar에 직접 접근
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let tabBarController = windowScene.windows.first?.rootViewController as? UITabBarController {
                        configureTabBar(tabBarController.tabBar)
                    }
                }
            }
        }
    }

    // MARK: - TabBar Configuration
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // iOS 18.5+: 항상 검정색 유지 (플로팅 탭바 스타일)
        // iOS 18.4 이하: 선택(검정), 미선택(회색) (기존 바닥 붙은 탭바)
        if #available(iOS 18.5, *) {
            appearance.stackedLayoutAppearance.normal.iconColor = .black
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.black]
            appearance.stackedLayoutAppearance.selected.iconColor = .black
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.black]
        } else {
            appearance.stackedLayoutAppearance.normal.iconColor = .systemGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
            appearance.stackedLayoutAppearance.selected.iconColor = .black
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.black]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    // 실제 UITabBar 인스턴스에 직접 설정
    private func configureTabBar(_ tabBar: UITabBar) {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        if #available(iOS 18.5, *) {
            appearance.stackedLayoutAppearance.normal.iconColor = .black
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.black]
            appearance.stackedLayoutAppearance.selected.iconColor = .black
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.black]
        } else {
            appearance.stackedLayoutAppearance.normal.iconColor = .systemGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
            appearance.stackedLayoutAppearance.selected.iconColor = .black
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.black]
        }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
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
