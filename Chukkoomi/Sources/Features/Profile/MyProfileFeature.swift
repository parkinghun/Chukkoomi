//
//  MyProfileFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

import ComposableArchitecture
import Foundation
import RealmSwift
import KakaoSDKUser
import AuthenticationServices

@Reducer
struct MyProfileFeature {
    
    // MARK: - State
    struct State: Equatable {
        var profile: Profile?
        var selectedTab: Tab = .posts
        var postImages: [PostImage] = []
        var bookmarkImages: [PostImage] = []
        var isLoading: Bool = false
        var profileImageData: Data?
        var isPresented: Bool = false // fullScreenCover로 표시되었는지

        // Pagination
        var postsNextCursor: String? = nil
        var bookmarksNextCursor: String? = nil
        var isLoadingNextPage: Bool = false

        @PresentationState var editProfile: EditProfileFeature.State?
        @PresentationState var userSearch: UserSearchFeature.State?
        @PresentationState var followList: FollowListFeature.State?
        @PresentationState var settingsMenu: ConfirmationDialogState<Action.SettingsMenuAction>?
        @PresentationState var postDetail: PostFeature.State?
        @PresentationState var alert: AlertState<Action.Alert>?
        
        // Computed properties
        var nickname: String {
            profile?.nickname ?? ""
        }
        
        var introduce: String {
            profile?.introduce ?? ""
        }
        
        var postCount: Int {
            profile?.posts.count ?? 0
        }
        
        var followerCount: Int {
            profile?.followers.count ?? 0
        }
        
        var followingCount: Int {
            profile?.following.count ?? 0
        }
        
        enum Tab: String, CaseIterable, Equatable {
            case posts = "게시글"
            case bookmarks = "북마크"
        }
    }
    
    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case searchButtonTapped
        case editProfileButtonTapped
        case addPostButtonTapped
        case tabSelected(State.Tab)
        case followerButtonTapped
        case followingButtonTapped
        case profileImageLoaded(Data)
        case settingsButtonTapped
        case logout
        case logoutCompleted
        case deleteAccount

        // API 응답
        case profileLoaded(Profile)
        case postImagesLoaded([PostImage], String?)
        case bookmarkImagesLoaded([PostImage], String?)

        // 게시물 fetch
        case fetchPosts
        case fetchBookmarks
        case loadNextPostsPage
        case loadNextBookmarksPage
        case postItemAppeared(String)

        // 게시물 상세
        case postItemTapped(String)
        case postLoaded(Post)

        // Navigation
        case editProfile(PresentationAction<EditProfileFeature.Action>)
        case userSearch(PresentationAction<UserSearchFeature.Action>)
        case followList(PresentationAction<FollowListFeature.Action>)
        case settingsMenu(PresentationAction<SettingsMenuAction>)
        case postDetail(PresentationAction<PostFeature.Action>)
        case alert(PresentationAction<Alert>)

        // Error handling
        case profileLoadFailed
        case deleteAccountFailed
        case postLoadFailed

        // Delegate
        case delegate(Delegate)

        enum SettingsMenuAction: Equatable {
            case logout
            case deleteAccount
        }

        enum Alert: Equatable {}

        enum Delegate: Equatable {
            case switchToPostTab
        }
    }
    
    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                // 데이터 초기화 (다른 탭에서 돌아올 때 업데이트하기 위해)
                state.postImages = []
                state.bookmarkImages = []
                state.postsNextCursor = nil
                state.bookmarksNextCursor = nil

                // 프로필 로드와 현재 탭 데이터 로드를 병렬로 실행
                let currentTab = state.selectedTab

                return .merge(
                    .run { send in
                        do {
                            let profile = try await NetworkManager.shared.performRequest(
                                ProfileRouter.lookupMe,
                                as: ProfileDTO.self
                            ).toDomain
                            await send(.profileLoaded(profile))
                        } catch {
                            await send(.profileLoadFailed)
                        }
                    },
                    currentTab == .posts ? .send(.fetchPosts) : .send(.fetchBookmarks)
                )
                
            case .searchButtonTapped:
                state.userSearch = UserSearchFeature.State()
                return .none

            case .followerButtonTapped:
                guard let profile = state.profile else { return .none }
                state.followList = FollowListFeature.State(
                    listType: .followers(users: profile.followers)
                )
                return .none

            case .followingButtonTapped:
                guard let profile = state.profile else { return .none }
                state.followList = FollowListFeature.State(
                    listType: .following(users: profile.following)
                )
                return .none
                
            case .addPostButtonTapped:
                // Post 탭으로 전환 요청
                return .send(.delegate(.switchToPostTab))
                
            case .editProfileButtonTapped:
                guard let profile = state.profile else { return .none }
                state.editProfile = EditProfileFeature.State(
                    profile: profile,
                    profileImageData: state.profileImageData
                )
                return .none

            case .profileImageLoaded(let data):
                state.profileImageData = data
                return .none
                
            case .tabSelected(let tab):
                state.selectedTab = tab
                switch tab {
                case .posts:
                    // 이미 로드되어 있으면 스킵
                    guard state.postImages.isEmpty else {
                        return .none
                    }
                    return .send(.fetchPosts)
                case .bookmarks:
                    // 이미 로드되어 있으면 스킵
                    guard state.bookmarkImages.isEmpty else {
                        return .none
                    }
                    return .send(.fetchBookmarks)
                }

            case .profileLoaded(let profile):
                state.profile = profile
                state.isLoading = false
                return .none
                
            case .postImagesLoaded(let images, let nextCursor):
                state.postImages.append(contentsOf: images)
                state.postsNextCursor = nextCursor
                state.isLoadingNextPage = false
                return .none

            case .bookmarkImagesLoaded(let images, let nextCursor):
                state.bookmarkImages.append(contentsOf: images)
                state.bookmarksNextCursor = nextCursor
                state.isLoadingNextPage = false
                return .none

            case .fetchPosts:
                guard let userId = UserDefaultsHelper.userId else {
                    return .none
                }

                return .run { send in
                    do {
                        let query = PostRouter.ListQuery(next: nil, limit: 12, category: ["all", "ulsan", "jeonbuk", "pohang", "suwonFC", "kimcheon", "gangwon", "jeju", "anyang", "seoul", "gwangju", "daejeon", "daegu"])
                        let response = try await NetworkManager.shared.performRequest(
                            PostRouter.fetchUserPosts(userId: userId, query),
                            as: PostListResponseDTO.self
                        )
                        dump(response)
                        let postImages = response.data.compactMap { dto -> PostImage? in
                            let post = dto.toDomain
                            guard post.files.count >= 2 else { return nil }
                            let thumbnailPath = post.files[1] // 썸네일
                            let originalPath = post.files[0] // 원본
                            let isVideo = MediaTypeHelper.isVideoPath(originalPath)
                            return PostImage(id: post.id, imagePath: thumbnailPath, isVideo: isVideo)
                        }

                        await send(.postImagesLoaded(postImages, response.nextCursor))
                    } catch {
                        await send(.postImagesLoaded([], nil))
                    }
                }
                
            case .fetchBookmarks:
                return .run { send in
                    do {
                        // 북마크한 게시물 조회 (페이지네이션)
                        let response = try await NetworkManager.shared.performRequest(
                            PostRouter.fetchBookmarkedPosts(next: nil, limit: 12),
                            as: PostListResponseDTO.self
                        )

                        // PostImage 배열로 변환 (썸네일 사용)
                        let bookmarkImages = response.data.compactMap { dto -> PostImage? in
                            let post = dto.toDomain
                            guard post.files.count >= 2 else { return nil }
                            let thumbnailPath = post.files[1] // 썸네일
                            let originalPath = post.files[0] // 원본
                            let isVideo = MediaTypeHelper.isVideoPath(originalPath)
                            return PostImage(id: post.id, imagePath: thumbnailPath, isVideo: isVideo)
                        }

                        await send(.bookmarkImagesLoaded(bookmarkImages, response.nextCursor))
                    } catch {
                        await send(.bookmarkImagesLoaded([], nil))
                    }
                }
                
            case .loadNextPostsPage:
                guard !state.isLoadingNextPage,
                      let next = state.postsNextCursor,
                      !next.isEmpty,
                      next != "0",
                      let userId = UserDefaultsHelper.userId else {
                    return .none
                }

                state.isLoadingNextPage = true
                return .run { send in
                    do {
                        let query = PostRouter.ListQuery(next: next, limit: 12, category: FootballTeams.teamsForHeader)
                        let response = try await NetworkManager.shared.performRequest(
                            PostRouter.fetchUserPosts(userId: userId, query),
                            as: PostListResponseDTO.self
                        )

                        let postImages = response.data.compactMap { dto -> PostImage? in
                            let post = dto.toDomain
                            guard post.files.count >= 2 else { return nil }
                            let thumbnailPath = post.files[1] // 썸네일
                            let originalPath = post.files[0] // 원본
                            let isVideo = MediaTypeHelper.isVideoPath(originalPath)
                            return PostImage(id: post.id, imagePath: thumbnailPath, isVideo: isVideo)
                        }

                        await send(.postImagesLoaded(postImages, response.nextCursor))
                    } catch {
                        await send(.postImagesLoaded([], nil))
                    }
                }

            case .loadNextBookmarksPage:
                guard !state.isLoadingNextPage,
                      let next = state.bookmarksNextCursor,
                      !next.isEmpty,
                      next != "0" else {
                    return .none
                }

                state.isLoadingNextPage = true
                return .run { send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            PostRouter.fetchBookmarkedPosts(next: next, limit: 12),
                            as: PostListResponseDTO.self
                        )

                        let bookmarkImages = response.data.compactMap { dto -> PostImage? in
                            let post = dto.toDomain
                            guard post.files.count >= 2 else { return nil }
                            let thumbnailPath = post.files[1] // 썸네일
                            let originalPath = post.files[0] // 원본
                            let isVideo = MediaTypeHelper.isVideoPath(originalPath)
                            return PostImage(id: post.id, imagePath: thumbnailPath, isVideo: isVideo)
                        }

                        await send(.bookmarkImagesLoaded(bookmarkImages, response.nextCursor))
                    } catch {
                        await send(.bookmarkImagesLoaded([], nil))
                    }
                }

            case .postItemAppeared(let id):
                // 현재 탭에 따라 다른 배열 체크
                switch state.selectedTab {
                case .posts:
                    if let index = state.postImages.firstIndex(where: { $0.id == id }),
                       index == state.postImages.count - 1 {
                        return .send(.loadNextPostsPage)
                    }
                case .bookmarks:
                    if let index = state.bookmarkImages.firstIndex(where: { $0.id == id }),
                       index == state.bookmarkImages.count - 1 {
                        return .send(.loadNextBookmarksPage)
                    }
                }
                return .none

            case .editProfile(.presented(.profileUpdated(let updatedProfile))):
                state.profile = updatedProfile
                return .none
                
            case .editProfile:
                return .none
                
            case .userSearch:
                return .none

            case .followList:
                return .none

            case .settingsButtonTapped:
                state.settingsMenu = ConfirmationDialogState {
                    TextState("설정")
                } actions: {
                    ButtonState(role: .destructive, action: .logout) {
                        TextState("로그아웃")
                    }
                    ButtonState(role: .destructive, action: .deleteAccount) {
                        TextState("회원탈퇴")
                    }
                }
                return .none

            case .settingsMenu(.presented(.logout)):
                return .send(.logout)

            case .settingsMenu(.presented(.deleteAccount)):
                return .send(.deleteAccount)

            case .deleteAccount:
                return .run { send in
                    do {
                        // 회원탈퇴 API 호출
                        let _ = try await NetworkManager.shared.performRequest(UserRouter.withdraw, as: WithdrawResponseDTO.self)

                        // 카카오 연결 해제 (카카오 로그인 사용자의 경우)
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            UserApi.shared.unlink { error in
                                // 에러가 있어도 계속 진행 (이미 연결 해제되었거나 카카오 로그인이 아닐 수 있음)
                                continuation.resume()
                            }
                        }

                        // 애플 로그인 Credential 해제 (iOS 13+)
                        // 애플은 명시적인 연결 해제 API가 없으므로 Credential 상태만 확인
                        if let userId = UserDefaultsHelper.userId {
                            let appleIDProvider = ASAuthorizationAppleIDProvider()
                            _ = try? await appleIDProvider.credentialState(forUserID: userId)
                            // 서버에서 이미 탈퇴 처리되었으므로 credential 상태와 무관하게 진행
                        }

                        // Realm에서 해당 사용자의 최근 검색어 모두 삭제
                        if let userId = UserDefaultsHelper.userId {
                            await MainActor.run {
                                do {
                                    let realm = try Realm()
                                    let userSearchWords = realm.objects(FeedRecentWordDTO.self)
                                        .filter("userId == %@", userId)

                                    try realm.write {
                                        realm.delete(userSearchWords)
                                    }
                                } catch {
                                }
                            }
                        }

                        // 성공 시 로그아웃 처리
                        await send(.logoutCompleted)
                    } catch {
                        await send(.deleteAccountFailed)
                    }
                }

            case .logout:
                // 실제 로그아웃 처리는 AppFeature에서 수행
                return .send(.logoutCompleted)

            case .logoutCompleted:
                // MainTabFeature를 통해 AppFeature로 전달되어 로그인 화면으로 전환
                return .none

            case .postItemTapped(let postId):
                // 단건 조회 후 PostDetail push
                return .run { send in
                    do {
                        let dto = try await NetworkManager.shared.performRequest(
                            PostRouter.fetchPost(postId),
                            as: PostResponseDTO.self
                        )
                        let post = dto.toDomain
                        await send(.postLoaded(post))
                    } catch {
                        await send(.postLoadFailed)
                    }
                }

            case .postLoaded(let post):
                // 단일 게시글을 위한 PostFeature.State 생성
                // postCells에 해당 게시글만 포함시키고, isDetailMode를 true로 설정
                var postFeatureState = PostFeature.State()
                postFeatureState.postCells = [PostCellFeature.State(post: post)]
                postFeatureState.nextCursor = "0" // 페이지네이션 비활성화
                postFeatureState.isDetailMode = true // 상세 모드 활성화 (새로고침 비활성화)
                state.postDetail = postFeatureState
                return .none

            case .postDetail:
                return .none

            case .settingsMenu:
                return .none

            case .profileLoadFailed:
                state.isLoading = false
                state.alert = AlertState {
                    TextState("프로필 로드 실패")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState("프로필 정보를 불러올 수 없습니다.\n다시 시도해주세요.")
                }
                return .none

            case .deleteAccountFailed:
                state.alert = AlertState {
                    TextState("회원탈퇴 실패")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState("회원탈퇴에 실패했습니다.\n다시 시도해주세요.")
                }
                return .none

            case .postLoadFailed:
                state.alert = AlertState {
                    TextState("게시글 로드 실패")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState("게시글을 불러올 수 없습니다.\n다시 시도해주세요.")
                }
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$editProfile, action: \.editProfile) {
            EditProfileFeature()
        }
        .ifLet(\.$userSearch, action: \.userSearch) {
            UserSearchFeature()
        }
        .ifLet(\.$followList, action: \.followList) {
            FollowListFeature()
        }
        .ifLet(\.$settingsMenu, action: \.settingsMenu)
        .ifLet(\.$postDetail, action: \.postDetail) {
            PostFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

// MARK: - Models
extension MyProfileFeature {
    // 게시글 그리드에 표시할 미디어 정보
    struct PostImage: Equatable, Identifiable {
        let id: String
        let imagePath: String
        var imageData: Data?
        let isVideo: Bool

        init(id: String, imagePath: String, imageData: Data? = nil, isVideo: Bool = false) {
            self.id = id
            self.imagePath = imagePath
            self.imageData = imageData
            self.isVideo = isVideo
        }
    }
}
