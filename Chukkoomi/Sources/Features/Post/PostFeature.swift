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

    private let postService: PostServiceProtocol

    init(postService: PostServiceProtocol = PostService.shared) {
        self.postService = postService
    }

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var postCells: IdentifiedArrayOf<PostCellFeature.State> = []
        var isLoading: Bool = false
        var errorMessage: String?
        var nextCursor: String?
        var searchHashtag: String? // 해시태그 검색용
        var teamInfo: KLeagueTeam? // 팀 정보 (팀별 게시글 조회용)
        var currentUserProfile: Profile? // 현재 유저의 프로필 (팔로잉 상태 확인용)
        var isDetailMode: Bool = false // 단일 게시글 상세 모드 (페이지네이션, 새로고침 비활성화)

        @Presents var hashtagSearch: PostFeature.State? // 해시태그 검색 화면
        @Presents var postCreate: PostCreateFeature.State? // 게시글 작성/수정 화면
        @Presents var sharePost: SharePostFeature.State? // 게시글 공유 시트
        @Presents var comment: CommentFeature.State? // 댓글 시트
        @Presents var myProfile: MyProfileFeature.State? // 내 프로필
        @Presents var otherProfile: OtherProfileFeature.State? // 다른 유저 프로필

        // 네비게이션 타이틀
        var navigationTitle: String {
            // 1순위: 해시태그 검색
            if let hashtag = searchHashtag {
                return "#\(hashtag)"
            }
            // 2순위: 팀별 게시글
            if let team = teamInfo {
                return team.koreanName
            }
            // 기본값
            return "게시글"
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case loadCurrentUserProfile
        case currentUserProfileLoaded(Result<Profile, Error>)
        case loadPosts
        case loadMorePosts
        case postsResponse(Result<PostListResponseDTO, Error>)
        case postCell(IdentifiedActionOf<PostCellFeature>)
        case hashtagSearch(PresentationAction<PostFeature.Action>)
        case postCreate(PresentationAction<PostCreateFeature.Action>)
        case sharePost(PresentationAction<SharePostFeature.Action>)
        case comment(PresentationAction<CommentFeature.Action>)
        case myProfile(PresentationAction<MyProfileFeature.Action>)
        case otherProfile(PresentationAction<OtherProfileFeature.Action>)

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.loadCurrentUserProfile, .loadCurrentUserProfile),
                 (.loadPosts, .loadPosts),
                 (.loadMorePosts, .loadMorePosts):
                return true
            case (.currentUserProfileLoaded, .currentUserProfileLoaded):
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
            case let (.hashtagSearch(lhs), .hashtagSearch(rhs)):
                return lhs == rhs
            case let (.postCreate(lhs), .postCreate(rhs)):
                return lhs == rhs
            case let (.sharePost(lhs), .sharePost(rhs)):
                return lhs == rhs
            case let (.comment(lhs), .comment(rhs)):
                return lhs == rhs
            case let (.myProfile(lhs), .myProfile(rhs)):
                return lhs == rhs
            case let (.otherProfile(lhs), .otherProfile(rhs)):
                return lhs == rhs
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
                // 현재 유저 프로필이 없으면 먼저 로드
                if state.currentUserProfile == nil {
                    return .merge(
                        .send(.loadCurrentUserProfile),
                        .send(.loadPosts)
                    )
                }
                return .send(.loadPosts)

            case .loadCurrentUserProfile:
                return .run { send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            ProfileRouter.lookupMe,
                            as: ProfileDTO.self
                        )
                        let profile = response.toDomain
                        await send(.currentUserProfileLoaded(.success(profile)))
                    } catch {
                        print("❌ 현재 유저 프로필 로드 실패: \(error)")
                        await send(.currentUserProfileLoaded(.failure(error)))
                    }
                }

            case let .currentUserProfileLoaded(.success(profile)):
                state.currentUserProfile = profile
                print("✅ 현재 유저 프로필 로드 완료 (팔로잉: \(profile.following.count)명)")
                return .none

            case .currentUserProfileLoaded(.failure):
                // 프로필 로드 실패해도 게시글은 계속 표시
                return .none

            case .loadPosts:
                state.isLoading = true
                state.errorMessage = nil

                // 해시태그 검색인지 일반 조회인지 분기
                if let searchHashtag = state.searchHashtag {
                    // 해시태그 검색
                    return .run { [postService] send in
                        do {
                            let query = PostRouter.HashtagQuery(
                                hashtag: searchHashtag,
                                next: nil,
                                limit: 20
                            )

                            let response = try await postService.searchByHashtag(query: query)

                            await send(.postsResponse(.success(response)))
                        } catch {
                            await send(.postsResponse(.failure(error)))
                        }
                    }
                } else {
                    // 일반 게시글 조회
                    return .run { [postService] send in
                        do {
                            let query = PostRouter.ListQuery(
                                next: nil,
                                limit: 20,
                                category: nil  // 전체 카테고리
                            )

                            let response = try await postService.fetchPosts(query: query)

                            await send(.postsResponse(.success(response)))
                        } catch {
                            await send(.postsResponse(.failure(error)))
                        }
                    }
                }

            case .loadMorePosts:
                guard !state.isLoading,
                      let nextCursor = state.nextCursor else {
                    return .none
                }

                state.isLoading = true

                return .run { [postService] send in
                    do {
                        let query = PostRouter.ListQuery(
                            next: nextCursor,
                            limit: 20,
                            category: nil
                        )

                        let response = try await postService.fetchPosts(query: query)

                        await send(.postsResponse(.success(response)))
                    } catch {
                        await send(.postsResponse(.failure(error)))
                    }
                }

            case let .postsResponse(.success(response)):
                state.isLoading = false
                state.nextCursor = response.nextCursor

                let newPosts = response.data.map { $0.toDomain }

                // 현재 유저의 팔로잉 목록에서 userId 배열 추출
                let followingUserIds = state.currentUserProfile?.following.map { $0.userId } ?? []

                // 각 게시글의 작성자가 팔로잉 목록에 있는지 확인하여 PostCellFeature.State 생성
                let newCells = newPosts.map { post -> PostCellFeature.State in
                    var cellState = PostCellFeature.State(post: post)

                    // 게시글 작성자가 팔로잉 목록에 있는지 확인
                    if let creatorId = post.creator?.userId {
                        cellState.isFollowing = followingUserIds.contains(creatorId)
                    }

                    return cellState
                }

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
                return handleCellDelegate(id: id, action: delegateAction, state: &state)

            case .postCell:
                return .none

            case .hashtagSearch:
                return .none

            case let .postCreate(.presented(.delegate(delegateAction))):
                // PostCreate에서의 delegate 액션 처리
                switch delegateAction {
                case .postCreated, .postUpdated:
                    print("📝 게시글 작성/수정 완료 - 리스트 새로고침")
                    // 게시글 리스트 새로고침
                    state.postCells = []
                    state.nextCursor = nil
                    // PostCreate 화면 닫기
                    state.postCreate = nil
                    return .send(.loadPosts)
                }

            case .postCreate:
                return .none

            case let .sharePost(.presented(.delegate(delegateAction))):
                // SharePost에서의 delegate 액션 처리
                switch delegateAction {
                case .dismiss:
                    state.sharePost = nil
                    return .none
                case .postShared:
                    state.sharePost = nil
                    // TODO: 공유 성공 토스트 표시
                    return .none
                }

            case .sharePost:
                return .none

            case let .comment(.presented(.delegate(.commentCountChanged(delta)))):
                // 댓글이 작성/삭제되면 해당 게시글의 댓글 수 업데이트
                guard let commentState = state.comment else { return .none }
                let postId = commentState.postId

                // 해당 게시글 셀의 commentCount 업데이트
                return .send(.postCell(.element(id: postId, action: .updateCommentCount(delta))))

            case .comment:
                return .none

            case .myProfile:
                return .none

            case .otherProfile:
                return .none
            }
        }
        .forEach(\.postCells, action: \.postCell) {
            PostCellFeature()
        }
        .ifLet(\.$hashtagSearch, action: \.hashtagSearch) {
            PostFeature()
        }
        .ifLet(\.$postCreate, action: \.postCreate) {
            PostCreateFeature()
        }
        .ifLet(\.$sharePost, action: \.sharePost) {
            SharePostFeature()
        }
        .ifLet(\.$comment, action: \.comment) {
            CommentFeature()
        }
        .ifLet(\.$myProfile, action: \.myProfile) {
            MyProfileFeature()
        }
        .ifLet(\.$otherProfile, action: \.otherProfile) {
            OtherProfileFeature()
        }
    }

    // MARK: - Delegate Handler
    private func handleCellDelegate(id: PostCellFeature.State.ID, action: PostCellFeature.Action.Delegate, state: inout State) -> Effect<Action> {
        switch action {
        case let .postTapped(postId):
            print("📄 게시글 탭: \(postId)")
            return .none

        case let .commentPost(postId):
            print("💬 댓글 탭: \(postId)")
            // 해당 게시글 찾기
            guard let post = state.postCells.first(where: { $0.post.id == postId })?.post else {
                print("❌ 댓글을 표시할 게시글을 찾을 수 없음: \(postId)")
                return .none
            }
            let creatorName = post.creator?.nickname ?? "작성자"
            // Comment 시트 표시
            state.comment = CommentFeature.State(postId: postId, postCreatorName: creatorName)
            return .none

        case let .sharePost(postId):
            // 해당 게시글 찾기
            guard let post = state.postCells.first(where: { $0.post.id == postId })?.post else {
                return .none
            }
            // SharePost 시트 표시
            state.sharePost = SharePostFeature.State(post: post)
            return .none

        case let .editPost(postId):
            print("✏️ 게시글 수정: \(postId)")
            // 해당 게시글 찾기
            guard let post = state.postCells.first(where: { $0.post.id == postId })?.post else {
                print("❌ 수정할 게시글을 찾을 수 없음: \(postId)")
                return .none
            }
            // PostCreate 화면으로 네비게이션 (수정 모드)
            state.postCreate = PostCreateFeature.State(post: post)
            return .none

        case let .postDeleted(postId):
            // 배열에서 해당 게시글 제거
            state.postCells.remove(id: postId)
            return .none

        case let .hashtagTapped(hashtag):
            // 새로운 PostFeature.State로 해시태그 검색 화면 push
            state.hashtagSearch = PostFeature.State(searchHashtag: hashtag)
            return .none

        case .myProfileTapped:
            // 내 프로필 화면으로 이동
            state.myProfile = MyProfileFeature.State()
            return .none

        case let .otherProfileTapped(userId):
            // 다른 유저 프로필 화면으로 이동
            state.otherProfile = OtherProfileFeature.State(userId: userId)
            return .none

        case let .followStatusChanged(userId, isFollowing):
            // 해당 유저의 모든 게시글에 팔로우 상태 동기화
            print("👥 팔로우 상태 변경: userId=\(userId), isFollowing=\(isFollowing)")

            // 1. 현재 유저 프로필의 following 목록 업데이트
            if let profile = state.currentUserProfile {
                var updatedFollowing = profile.following

                if isFollowing {
                    // 팔로우: following 목록에 추가
                    // 해당 유저 정보를 게시글에서 찾기
                    if let userToFollow = state.postCells.first(where: { $0.post.creator?.userId == userId })?.post.creator {
                        if !updatedFollowing.contains(where: { $0.userId == userId }) {
                            updatedFollowing.append(userToFollow)
                            state.currentUserProfile = Profile(
                                userId: profile.userId,
                                email: profile.email,
                                nickname: profile.nickname,
                                profileImage: profile.profileImage,
                                introduce: profile.introduce,
                                followers: profile.followers,
                                following: updatedFollowing,
                                posts: profile.posts
                            )
                            print("✅ Following 목록에 추가: \(userToFollow.nickname)")
                        }
                    }
                } else {
                    // 언팔로우: following 목록에서 제거
                    updatedFollowing.removeAll { $0.userId == userId }
                    state.currentUserProfile = Profile(
                        userId: profile.userId,
                        email: profile.email,
                        nickname: profile.nickname,
                        profileImage: profile.profileImage,
                        introduce: profile.introduce,
                        followers: profile.followers,
                        following: updatedFollowing,
                        posts: profile.posts
                    )
                    print("✅ Following 목록에서 제거: userId=\(userId)")
                }
            }

            // 2. 모든 게시글을 순회하며 같은 유저의 게시글 찾아서 업데이트
            for postCell in state.postCells {
                if let creatorId = postCell.post.creator?.userId, creatorId == userId {
                    // 해당 게시글의 팔로우 상태 업데이트
                    state.postCells[id: postCell.id]?.isFollowing = isFollowing
                    print("✅ 게시글 \(postCell.post.id)의 팔로우 상태 업데이트: \(isFollowing)")
                }
            }

            return .none
        }
    }
}
