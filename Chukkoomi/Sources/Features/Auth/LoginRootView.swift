//
//  LoginRootView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import SwiftUI
import ComposableArchitecture

struct LoginRootView: View {

    let loginStore = Store(initialState: LoginFeature.State()) {
        LoginFeature()
    }

    var body: some View {
        NavigationStack {
            LoginView(store: loginStore)
        }
    }
}
