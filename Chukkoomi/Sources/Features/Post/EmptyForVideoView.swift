//
//  EmptyForVideoView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import SwiftUI
import ComposableArchitecture

// MARK: - Feature
struct EmptyForVideoFeature: Reducer {
    struct State: Equatable {
        @PresentationState var galleryPicker: GalleryPickerFeature.State?
    }

    @CasePathable
    enum Action: Equatable {
        case editVideoButtonTapped
        case galleryPicker(PresentationAction<GalleryPickerFeature.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .editVideoButtonTapped:
                state.galleryPicker = GalleryPickerFeature.State(pickerMode: .post)
                return .none

            case .galleryPicker(.presented(.cancel)):
                state.galleryPicker = nil
                return .none

            case .galleryPicker:
                return .none
            }
        }
        .ifLet(\.$galleryPicker, action: \.galleryPicker) {
            GalleryPickerFeature()
        }
    }
}

// MARK: - View
struct EmptyForVideoView: View {
    let store: StoreOf<EmptyForVideoFeature>

    var body: some View {
        Button {
            store.send(.editVideoButtonTapped)
        } label: {
            Text("Edit Video")
        }
        .fullScreenCover(
            store: store.scope(
                state: \.$galleryPicker,
                action: \.galleryPicker
            )
        ) { store in
            NavigationStack {
                GalleryPickerView(store: store)
            }
        }
    }
}
