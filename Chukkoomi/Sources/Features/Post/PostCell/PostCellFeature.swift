//
//  PostCellFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct PostCellFeature {

    @ObservableState
    struct State: Equatable, Identifiable {
        let post: Post
        var isLiked: Bool
        var isBookmarked: Bool

        var id: String {
            post.id
        }

        var postId: String? {
            post.id
        }

        init(post: Post) {
            self.post = post
            self.isLiked = false
            self.isBookmarked = false
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        // User Actions
        case postTapped
        case likeTapped
        case commentTapped
        case shareTapped
        case bookmarkTapped
        case followTapped

        // Delegate Actions (부모에게 알림)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case postTapped(String)
            case likePost(String)
            case commentPost(String)
            case sharePost(String)
            case bookmarkPost(String)
            case followUser(String)
        }
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .postTapped:
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.postTapped(postId)))

            case .likeTapped:
                guard let postId = state.postId else { return .none }
                state.isLiked.toggle()
                return .send(.delegate(.likePost(postId)))

            case .commentTapped:
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.commentPost(postId)))

            case .shareTapped:
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.sharePost(postId)))

            case .bookmarkTapped:
                guard let postId = state.postId else { return .none }
                state.isBookmarked.toggle()
                return .send(.delegate(.bookmarkPost(postId)))

            case .followTapped:
                guard let userId = state.post.creator?.userId else { return .none }
                return .send(.delegate(.followUser(userId)))

            case .delegate:
                return .none
            }
        }
    }
}
