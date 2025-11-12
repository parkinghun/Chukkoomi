//
//  PostFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct PostFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var postCells: IdentifiedArrayOf<PostCellFeature.State> = []
        var isLoading: Bool = false
        var errorMessage: String?
        var nextCursor: String?
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case loadPosts
        case loadMorePosts
        case postsResponse(Result<PostListResponseDTO, Error>)
        case postCell(IdentifiedActionOf<PostCellFeature>)

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.loadPosts, .loadPosts),
                 (.loadMorePosts, .loadMorePosts):
                return true
            case let (.postsResponse(lhsResult), .postsResponse(rhsResult)):
                switch (lhsResult, rhsResult) {
                case (.success(let lhsDTO), .success(let rhsDTO)):
                    return lhsDTO.data.count == rhsDTO.data.count
                case (.failure, .failure):
                    return true
                default:
                    return false
                }
            case let (.postCell(lhsAction), .postCell(rhsAction)):
                return lhsAction == rhsAction
            default:
                return false
            }
        }
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.postCells.isEmpty else { return .none }
                return .send(.loadPosts)

            case .loadPosts:
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    do {
                        let query = PostRouter.ListQuery(
                            next: nil,
                            limit: 20,
                            category: nil  // 전체 카테고리
                        )

                        let response = try await NetworkManager.shared.performRequest(
                            PostRouter.fetchPosts(query),
                            as: PostListResponseDTO.self
                        )

                        await send(.postsResponse(.success(response)))
                    } catch {
                        await send(.postsResponse(.failure(error)))
                    }
                }

            case .loadMorePosts:
                guard !state.isLoading,
                      let nextCursor = state.nextCursor else {
                    return .none
                }

                state.isLoading = true

                return .run { send in
                    do {
                        let query = PostRouter.ListQuery(
                            next: nextCursor,
                            limit: 20,
                            category: nil
                        )

                        let response = try await NetworkManager.shared.performRequest(
                            PostRouter.fetchPosts(query),
                            as: PostListResponseDTO.self
                        )

                        await send(.postsResponse(.success(response)))
                    } catch {
                        await send(.postsResponse(.failure(error)))
                    }
                }

            case let .postsResponse(.success(response)):
                state.isLoading = false
                state.nextCursor = response.nextCursor

                let newPosts = response.data.map { $0.toDomain }
                let newCells = newPosts.map { PostCellFeature.State(post: $0) }

                // 중복 제거하며 추가
                for cell in newCells where !state.postCells.contains(where: { $0.id == cell.id }) {
                    state.postCells.append(cell)
                }

                print("📱 게시글 \(response.data.count)개 로드 완료 (전체: \(state.postCells.count)개)")
                return .none

            case let .postsResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                print("❌ 게시글 로드 실패: \(error.localizedDescription)")
                return .none

            case let .postCell(.element(id, .delegate(delegateAction))):
                return handleCellDelegate(id: id, action: delegateAction)

            case .postCell:
                return .none
            }
        }
        .forEach(\.postCells, action: \.postCell) {
            PostCellFeature()
        }
    }

    // MARK: - Delegate Handler
    private func handleCellDelegate(id: PostCellFeature.State.ID, action: PostCellFeature.Action.Delegate) -> Effect<Action> {
        switch action {
        case let .postTapped(postId):
            print("📄 게시글 탭: \(postId)")
            return .none

        case let .likePost(postId):
            print("❤️ 좋아요 탭: \(postId)")
            // TODO: API 호출 - 좋아요 토글
            return .none

        case let .commentPost(postId):
            print("💬 댓글 탭: \(postId)")
            // TODO: 댓글 화면으로 이동
            return .none

        case let .sharePost(postId):
            print("📤 공유 탭: \(postId)")
            // TODO: 공유 시트 표시
            return .none

        case let .bookmarkPost(postId):
            print("🔖 북마크 탭: \(postId)")
            // TODO: API 호출 - 북마크 토글
            return .none

        case let .followUser(userId):
            print("➕ 팔로우 탭: \(userId)")
            // TODO: API 호출 - 팔로우 토글
            return .none
        }
    }
}
