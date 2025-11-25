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
        var commentCount: Int
        var isBookmarked: Bool
        var isFollowing: Bool
        var likedUsers: [User] = [] // 좋아요 누른 사용자들 (최대 3명)
        var isLoadingLikedUsers: Bool = false

        @Presents var menu: ConfirmationDialogState<Action.Menu>?
        @Presents var deleteAlert: AlertState<Action.DeleteAlert>?

        var id: String {
            post.id
        }

        var postId: String? {
            post.id
        }

        // 본인이 작성한 게시글인지 확인
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

            // 본인의 userId 가져오기
            let myUserId = UserDefaultsHelper.userId

            // 좋아요 초기 상태 설정
            if let myUserId = myUserId, let likes = post.likes {
                self.isLiked = likes.contains(myUserId)
            } else {
                self.isLiked = false
            }

            // 북마크 초기 상태 설정
            if let myUserId = myUserId, let bookmarks = post.bookmarks {
                self.isBookmarked = bookmarks.contains(myUserId)
            } else {
                self.isBookmarked = false
            }

            // 팔로우 초기 상태 설정 (추후 Profile 정보로 확인 필요)
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
        // User Actions
        case postTapped
        case profileTapped
        case likeTapped
        case commentTapped
        case shareTapped
        case bookmarkTapped
        case followTapped
        case menuTapped
        case hashtagTapped(String)

        // Comment Count Update
        case updateCommentCount(Int) // delta: +1 or -1

        // Follow Status Update
        case updateFollowStatus(Bool) // 팔로우 상태 업데이트

        // Liked Users Loading
        case loadLikedUsers
        case likedUsersResponse(Result<[User], Error>)

        // Menu Actions
        case menu(PresentationAction<Menu>)

        // Delete Alert Actions
        case deleteAlert(PresentationAction<DeleteAlert>)
        case deleteResponse(Result<Void, Error>)

        // Debounced Network Actions
        case debouncedToggleRequest(ToggleType)
        case toggleResponse(ToggleType, Result<PostLikeResponseDTO, Error>)

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
                 (.loadLikedUsers, .loadLikedUsers):
                return true
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

            case let .hashtagTapped(hashtag):
                return .send(.delegate(.hashtagTapped(hashtag)))

            case .commentTapped:
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.commentPost(postId)))

            case let .updateCommentCount(delta):
                state.commentCount += delta
                return .none

            case let .updateFollowStatus(isFollowing):
                state.isFollowing = isFollowing
                return .none

            case .loadLikedUsers:
                // 이미 로딩 중이거나 이미 로드했으면 스킵
                guard !state.isLoadingLikedUsers && state.likedUsers.isEmpty else {
                    return .none
                }

                // likes가 없거나 비어있으면 스킵
                guard let likes = state.post.likes, !likes.isEmpty else {
                    return .none
                }

                // 처음 3명만 가져오기
                let userIdsToFetch = Array(likes.prefix(3))
                state.isLoadingLikedUsers = true

                return .run { send in
                    do {
                        // 병렬로 프로필 조회
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
                // 낙관적 UI 업데이트 (즉시 상태 변경)
                state.isFollowing.toggle()

                // 디바운스를 통해 마지막 상태만 네트워크 전송
                return .send(.debouncedToggleRequest(.follow))
                    .debounce(id: ToggleType.follow, for: .milliseconds(300), scheduler: DispatchQueue.main)

            case .menuTapped:
                if state.isMyPost {
                    // 내 게시물: 수정하기/삭제하기
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
                    // 다른 사람 게시물: 팔로우/팔로잉
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
                // 삭제 확인 Alert 띄우기
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
                // 팔로우 토글
                return .send(.followTapped)

            case .menu:
                return .none

            case .deleteAlert(.presented(.confirmDelete)):
                // 삭제 확인 -> API 호출
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
                // 삭제 성공 -> 부모에게 알림
                print("✅ 게시글 삭제 성공")
                guard let postId = state.postId else { return .none }
                return .send(.delegate(.postDeleted(postId)))

            case let .deleteResponse(.failure(error)):
                // 삭제 실패
                print("❌ 게시글 삭제 실패: \(error)")
                // TODO: 에러 토스트 표시
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$menu, action: \.menu)
        .ifLet(\.$deleteAlert, action: \.deleteAlert)
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
                    // FollowResponse를 PostLikeResponseDTO와 호환되도록 변환
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
            // 서버 응답과 현재 상태가 일치하는지 확인
            if state.isLiked != response.likeStatus {
                state.isLiked = response.likeStatus
                state.likeCount += response.likeStatus ? 1 : -1
            }

        case .bookmark:
            print("북마크 성공: \(response.likeStatus)")
            // 서버 응답과 현재 상태가 일치하는지 확인
            if state.isBookmarked != response.likeStatus {
                state.isBookmarked = response.likeStatus
            }

        case .follow:
            print("팔로우 성공: \(response.likeStatus)")
            // 서버 응답과 현재 상태가 일치하는지 확인
            if state.isFollowing != response.likeStatus {
                state.isFollowing = response.likeStatus
            }
            // 팔로우 상태 변경을 부모에게 알림
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
            // 실패 시 상태 롤백
            state.isLiked.toggle()
            state.likeCount += state.isLiked ? 1 : -1

        case .bookmark:
            print("북마크 실패: \(error)")
            // 실패 시 상태 롤백
            state.isBookmarked.toggle()

        case .follow:
            print("팔로우 실패: \(error)")
            // 실패 시 상태 롤백
            state.isFollowing.toggle()
        }
        return .none
    }
}
