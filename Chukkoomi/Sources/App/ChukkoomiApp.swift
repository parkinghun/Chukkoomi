//
//  ChukkoomiApp.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/4/25.
//

import SwiftUI
import ComposableArchitecture

@main
struct ChukkoomiApp: App {
    var body: some Scene {
        WindowGroup {
            AppView(
                store: Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            )
        }
    }
}
