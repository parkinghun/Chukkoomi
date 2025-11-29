//
//  AppView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/12/25.
//

import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Group {
            if store.isCheckingAuth {
                // 인증 체크 중 - 스플래시 화면
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if store.isLoggedIn {
                // 로그인 상태 - MainTabView 표시
                if let mainTabStore = store.scope(state: \.mainTabState, action: \.mainTab) {
                    MainTabView(store: mainTabStore)
                }
            } else {
                // 비로그인 상태 - LoginView 표시
                if let loginStore = store.scope(state: \.loginState, action: \.login) {
                    NavigationStack {
                        LoginView(store: loginStore)
                    }
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}
