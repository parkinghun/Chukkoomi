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
        var likeCount: Int
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
            self.likeCount = post.likes?.count ?? 0
            self.isBookmarked = false
        }
    }

    // MARK: - Toggle Type
    enum ToggleType: Equatable, Hashable {
        case like
        case bookmark
        // case follow // 나중에 추가 예정
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

        // Debounced Network Actions
        case debouncedToggleRequest(ToggleType)
        case toggleResponse(ToggleType, Result<PostLikeResponseDTO, Error>)

        // Delegate Actions (부모에게 알림)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case postTapped(String)
            case commentPost(String)
            case sharePost(String)
            case followUser(String)
        }

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.postTapped, .postTapped),
                 (.likeTapped, .likeTapped),
                 (.commentTapped, .commentTapped),
                 (.shareTapped, .shareTapped),
                 (.bookmarkTapped, .bookmarkTapped),
                 (.followTapped, .followTapped):
                return true
            case let (.debouncedToggleRequest(lhs), .debouncedToggleRequest(rhs)):
                return lhs == rhs
            case let (.toggleResponse(lhsType, _), .toggleResponse(rhsType, _)):
                return lhsType == rhsType
            case let (.delegate(lhs), .delegate(rhs)):
                return lhs == rhs
            default:
                return false
            }
        }
    }

    // MARK: - Dependencies
    @Dependency(\.continuousClock) var clock

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .postTapped:
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.postTapped(postId)))

            case .likeTapped:
                // 낙관적 UI 업데이트 (즉시 상태 변경)
                state.isLiked.toggle()
                state.likeCount += state.isLiked ? 1 : -1

                // 디바운스를 통해 마지막 상태만 네트워크 전송
                return .send(.debouncedToggleRequest(.like))
                    .debounce(id: ToggleType.like, for: .milliseconds(300), scheduler: DispatchQueue.main)

            case .bookmarkTapped:
                // 낙관적 UI 업데이트 (즉시 상태 변경)
                state.isBookmarked.toggle()

                // 디바운스를 통해 마지막 상태만 네트워크 전송
                return .send(.debouncedToggleRequest(.bookmark))
                    .debounce(id: ToggleType.bookmark, for: .milliseconds(300), scheduler: DispatchQueue.main)

            case let .debouncedToggleRequest(toggleType):
                return handleToggleRequest(state: state, toggleType: toggleType)

            case let .toggleResponse(toggleType, .success(response)):
                return handleToggleSuccess(state: &state, toggleType: toggleType, response: response)

            case let .toggleResponse(toggleType, .failure(error)):
                return handleToggleFailure(state: &state, toggleType: toggleType, error: error)

            case .commentTapped:
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.commentPost(postId)))

            case .shareTapped:
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.sharePost(postId)))

            case .followTapped:
                guard let userId = state.post.creator?.userId else { return .none }
                return .send(.delegate(.followUser(userId)))

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Private Helper Methods

    /// 토글 요청 처리 (좋아요, 북마크 공통)
    private func handleToggleRequest(state: State, toggleType: ToggleType) -> Effect<Action> {
        guard let postId = state.postId else { return .none }

        switch toggleType {
        case .like:
            let currentStatus = state.isLiked
            return .run { send in
                do {
                    let response = try await PostService.shared.toggleLike(
                        postId: postId,
                        likeStatus: currentStatus
                    )
                    await send(.toggleResponse(.like, .success(response)))
                } catch {
                    await send(.toggleResponse(.like, .failure(error)))
                }
            }

        case .bookmark:
            let currentStatus = state.isBookmarked
            return .run { send in
                do {
                    let response = try await PostService.shared.toggleBookmark(
                        postId: postId,
                        likeStatus: currentStatus
                    )
                    await send(.toggleResponse(.bookmark, .success(response)))
                } catch {
                    await send(.toggleResponse(.bookmark, .failure(error)))
                }
            }
        }
    }

    /// 토글 성공 처리
    private func handleToggleSuccess(
        state: inout State,
        toggleType: ToggleType,
        response: PostLikeResponseDTO
    ) -> Effect<Action> {
        switch toggleType {
        case .like:
            print("✅ 좋아요 성공: \(response.likeStatus)")
            // 서버 응답과 현재 상태가 일치하는지 확인
            if state.isLiked != response.likeStatus {
                state.isLiked = response.likeStatus
                state.likeCount += response.likeStatus ? 1 : -1
            }

        case .bookmark:
            print("✅ 북마크 성공: \(response.likeStatus)")
            // 서버 응답과 현재 상태가 일치하는지 확인
            if state.isBookmarked != response.likeStatus {
                state.isBookmarked = response.likeStatus
            }
        }
        return .none
    }

    /// 토글 실패 처리 (상태 롤백)
    private func handleToggleFailure(
        state: inout State,
        toggleType: ToggleType,
        error: Error
    ) -> Effect<Action> {
        switch toggleType {
        case .like:
            print("❌ 좋아요 실패: \(error)")
            // 실패 시 상태 롤백
            state.isLiked.toggle()
            state.likeCount += state.isLiked ? 1 : -1

        case .bookmark:
            print("❌ 북마크 실패: \(error)")
            // 실패 시 상태 롤백
            state.isBookmarked.toggle()
        }
        return .none
    }
}
