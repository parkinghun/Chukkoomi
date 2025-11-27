//
//  PostCellFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import ComposableArchitecture
import Foundation
import UIKit

@Reducer
struct PostCellFeature {

    @ObservableState
    struct State: Equatable, Identifiable {
        let post: Post
        var isLiked: Bool
        var likeCount: Int
        var commentCount: Int
        var isBookmarked: Bool
        var isFollowing: Bool
        var likedUsers: [User] = []
        var isLoadingLikedUsers: Bool = false
        var currentImage: UIImage? = nil // 로드된 이미지 저장

        @Presents var menu: ConfirmationDialogState<Action.Menu>?
        @Presents var deleteAlert: AlertState<Action.DeleteAlert>?
        @Presents var imageViewer: ImageViewerFeature.State?

        var id: String {
            post.id
        }

        var postId: String? {
            post.id
        }

        var isMyPost: Bool {
            guard let myUserId = UserDefaultsHelper.userId,
                  let creatorId = post.creator?.userId else {
                return false
            }
            return myUserId == creatorId
        }

        init(post: Post) {
            self.post = post
            self.likeCount = post.likes?.count ?? 0
            self.commentCount = post.commentCount ?? 0

            let myUserId = UserDefaultsHelper.userId

            if let myUserId = myUserId, let likes = post.likes {
                self.isLiked = likes.contains(myUserId)
            } else {
                self.isLiked = false
            }

            if let myUserId = myUserId, let bookmarks = post.bookmarks {
                self.isBookmarked = bookmarks.contains(myUserId)
            } else {
                self.isBookmarked = false
            }

            self.isFollowing = false
        }
    }

    // MARK: - Toggle Type
    enum ToggleType: Equatable, Hashable {
        case like
        case bookmark
        case follow
    }

    // MARK: - Action
    enum Action: Equatable {
        case postTapped
        case profileTapped
        case likeTapped
        case commentTapped
        case shareTapped
        case bookmarkTapped
        case followTapped
        case menuTapped
        case hashtagTapped(String)
        case imageTapped
        case imageLoaded(UIImage)

        // Comment Count Update
        case updateCommentCount(Int) // delta: +1 or -1
        case updateFollowStatus(Bool) // 팔로우 상태 업데이트
        case loadLikedUsers
        case likedUsersResponse(Result<[User], Error>)
        case menu(PresentationAction<Menu>)
        case deleteAlert(PresentationAction<DeleteAlert>)
        case deleteResponse(Result<Void, Error>)
        case debouncedToggleRequest(ToggleType)
        case toggleResponse(ToggleType, Result<PostLikeResponseDTO, Error>)

        // Image Viewer
        case imageViewer(PresentationAction<ImageViewerFeature.Action>)

        // Delegate Actions (부모에게 알림)
        case delegate(Delegate)

        enum Menu: Equatable {
            case editPost
            case deletePost
            case toggleFollow
        }

        enum DeleteAlert: Equatable {
            case confirmDelete
        }

        enum Delegate: Equatable {
            case postTapped(String)
            case commentPost(String)
            case sharePost(String)
            case editPost(String)
            case postDeleted(String)
            case hashtagTapped(String)
            case myProfileTapped
            case otherProfileTapped(String) // userId
            case followStatusChanged(userId: String, isFollowing: Bool)
        }

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.postTapped, .postTapped),
                 (.profileTapped, .profileTapped),
                 (.likeTapped, .likeTapped),
                 (.commentTapped, .commentTapped),
                 (.shareTapped, .shareTapped),
                 (.bookmarkTapped, .bookmarkTapped),
                 (.followTapped, .followTapped),
                 (.menuTapped, .menuTapped),
                 (.imageTapped, .imageTapped),
                 (.loadLikedUsers, .loadLikedUsers):
                return true
            case (.imageLoaded, .imageLoaded):
                return true  // UIImage는 비교 불가
            case let (.hashtagTapped(lhs), .hashtagTapped(rhs)):
                return lhs == rhs
            case let (.updateCommentCount(lhs), .updateCommentCount(rhs)):
                return lhs == rhs
            case let (.updateFollowStatus(lhs), .updateFollowStatus(rhs)):
                return lhs == rhs
            case (.likedUsersResponse, .likedUsersResponse):
                return true
            case let (.menu(lhs), .menu(rhs)):
                return lhs == rhs
            case let (.deleteAlert(lhs), .deleteAlert(rhs)):
                return lhs == rhs
            case (.deleteResponse, .deleteResponse):
                return true
            case let (.debouncedToggleRequest(lhs), .debouncedToggleRequest(rhs)):
                return lhs == rhs
            case let (.toggleResponse(lhsType, _), .toggleResponse(rhsType, _)):
                return lhsType == rhsType
            case let (.imageViewer(lhs), .imageViewer(rhs)):
                return lhs == rhs
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

            case .profileTapped:
                guard let userId = state.post.creator?.userId else { return .none }
                let myUserId = UserDefaultsHelper.userId

                if userId == myUserId {
                    return .send(.delegate(.myProfileTapped))
                } else {
                    return .send(.delegate(.otherProfileTapped(userId)))
                }

            case .likeTapped:
                state.isLiked.toggle()
                state.likeCount += state.isLiked ? 1 : -1

                return .send(.debouncedToggleRequest(.like))
                    .debounce(id: ToggleType.like, for: .milliseconds(300), scheduler: DispatchQueue.main)

            case .bookmarkTapped:
                state.isBookmarked.toggle()

                return .send(.debouncedToggleRequest(.bookmark))
                    .debounce(id: ToggleType.bookmark, for: .milliseconds(300), scheduler: DispatchQueue.main)

            case let .debouncedToggleRequest(toggleType):
                return handleToggleRequest(state: state, toggleType: toggleType)

            case let .toggleResponse(toggleType, .success(response)):
                return handleToggleSuccess(state: &state, toggleType: toggleType, response: response)

            case let .toggleResponse(toggleType, .failure(error)):
                return handleToggleFailure(state: &state, toggleType: toggleType, error: error)

            case let .hashtagTapped(hashtag):
                return .send(.delegate(.hashtagTapped(hashtag)))

            case .commentTapped:
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.commentPost(postId)))

            case let .imageLoaded(image):
                state.currentImage = image
                return .none

            case .imageTapped:
                guard let image = state.currentImage else { return .none }
                state.imageViewer = ImageViewerFeature.State(image: image)
                return .none

            case .imageViewer(.presented(.delegate(.dismiss))):
                state.imageViewer = nil
                return .none

            case .imageViewer:
                return .none

            case let .updateCommentCount(delta):
                state.commentCount += delta
                return .none

            case let .updateFollowStatus(isFollowing):
                state.isFollowing = isFollowing
                return .none

            case .loadLikedUsers:
                guard !state.isLoadingLikedUsers && state.likedUsers.isEmpty else {
                    return .none
                }

                guard let likes = state.post.likes, !likes.isEmpty else {
                    return .none
                }

                let userIdsToFetch = Array(likes.prefix(3))
                state.isLoadingLikedUsers = true

                return .run { send in
                    do {
                        let users = try await withThrowingTaskGroup(of: User?.self) { group in
                            for userId in userIdsToFetch {
                                group.addTask {
                                    do {
                                        let response = try await NetworkManager.shared.performRequest(
                                            ProfileRouter.lookupOther(id: userId),
                                            as: ProfileDTO.self
                                        )
                                        return response.toUser
                                    } catch {
                                        print("프로필 로드 실패 (userId: \(userId)): \(error)")
                                        return nil
                                    }
                                }
                            }

                            var fetchedUsers: [User] = []
                            for try await user in group {
                                if let user = user {
                                    fetchedUsers.append(user)
                                }
                            }
                            return fetchedUsers
                        }

                        await send(.likedUsersResponse(.success(users)))
                    } catch {
                        await send(.likedUsersResponse(.failure(error)))
                    }
                }

            case let .likedUsersResponse(.success(users)):
                state.isLoadingLikedUsers = false
                state.likedUsers = users
                return .none

            case .likedUsersResponse(.failure):
                state.isLoadingLikedUsers = false
                return .none

            case .shareTapped:
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.sharePost(postId)))

            case .followTapped:
                state.isFollowing.toggle()

                return .send(.debouncedToggleRequest(.follow))
                    .debounce(id: ToggleType.follow, for: .milliseconds(300), scheduler: DispatchQueue.main)

            case .menuTapped:
                if state.isMyPost {
                    state.menu = ConfirmationDialogState {
                        TextState("게시글 관리")
                    } actions: {
                        ButtonState(action: .editPost) {
                            TextState("수정하기")
                        }
                        ButtonState(role: .destructive, action: .deletePost) {
                            TextState("삭제하기")
                        }
                        ButtonState(role: .cancel) {
                            TextState("취소")
                        }
                    }
                } else {
                    state.menu = ConfirmationDialogState {
                        TextState("사용자 관리")
                    } actions: {
                        ButtonState(action: .toggleFollow) {
                            TextState(state.isFollowing ? "팔로우 취소" : "팔로우")
                        }
                        ButtonState(role: .cancel) {
                            TextState("취소")
                        }
                    }
                }
                return .none

            case .menu(.presented(.editPost)):
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.editPost(postId)))

            case .menu(.presented(.deletePost)):
                state.deleteAlert = AlertState {
                    TextState("게시글을 삭제하시겠어요?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("삭제하기")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("삭제한 게시글을 복구할 수 없습니다.")
                }
                return .none

            case .menu(.presented(.toggleFollow)):
                return .send(.followTapped)

            case .menu:
                return .none

            case .deleteAlert(.presented(.confirmDelete)):
                guard let postId = state.postId else { return .none }
                return .run { send in
                    do {
                        try await PostService.shared.deletePost(postId: postId)
                        await send(.deleteResponse(.success(())))
                    } catch {
                        await send(.deleteResponse(.failure(error)))
                    }
                }

            case .deleteAlert:
                return .none

            case .deleteResponse(.success):
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.postDeleted(postId)))

            case .deleteResponse(.failure(_)):
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$menu, action: \.menu)
        .ifLet(\.$deleteAlert, action: \.deleteAlert)
        .ifLet(\.$imageViewer, action: \.imageViewer) {
            ImageViewerFeature()
        }
    }

    // MARK: - Private Helper Methods

    /// 토글 요청 처리 (좋아요, 북마크, 팔로우 공통)
    private func handleToggleRequest(state: State, toggleType: ToggleType) -> Effect<Action> {
        switch toggleType {
        case .like:
            guard let postId = state.postId else { return .none }
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
            guard let postId = state.postId else { return .none }
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

        case .follow:
            guard let userId = state.post.creator?.userId else { return .none }
            let currentStatus = state.isFollowing
            return .run { send in
                do {
                    let response = try await NetworkManager.shared.performRequest(
                        FollowRouter.follow(id: userId, follow: currentStatus),
                        as: FollowResponseDTO.self
                    )
                    let followResponse = response.toDomain
                    let adaptedResponse = PostLikeResponseDTO(likeStatus: followResponse.status)
                    await send(.toggleResponse(.follow, .success(adaptedResponse)))
                } catch {
                    await send(.toggleResponse(.follow, .failure(error)))
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
            print("좋아요 성공: \(response.likeStatus)")
            if state.isLiked != response.likeStatus {
                state.isLiked = response.likeStatus
                state.likeCount += response.likeStatus ? 1 : -1
            }

        case .bookmark:
            print("북마크 성공: \(response.likeStatus)")
            if state.isBookmarked != response.likeStatus {
                state.isBookmarked = response.likeStatus
            }

        case .follow:
            print("팔로우 성공: \(response.likeStatus)")
            if state.isFollowing != response.likeStatus {
                state.isFollowing = response.likeStatus
            }
            if let userId = state.post.creator?.userId {
                return .send(.delegate(.followStatusChanged(userId: userId, isFollowing: response.likeStatus)))
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
            print("좋아요 실패: \(error)")
            state.isLiked.toggle()
            state.likeCount += state.isLiked ? 1 : -1

        case .bookmark:
            print("북마크 실패: \(error)")
            state.isBookmarked.toggle()

        case .follow:
            print("팔로우 실패: \(error)")
            state.isFollowing.toggle()
        }
        return .none
    }
}
