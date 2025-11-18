//
//  MyProfileFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

import ComposableArchitecture
import Foundation
import RealmSwift

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

        @PresentationState var editProfile: EditProfileFeature.State?
        @PresentationState var userSearch: UserSearchFeature.State?
        @PresentationState var followList: FollowListFeature.State?
        @PresentationState var settingsMenu: ConfirmationDialogState<Action.SettingsMenuAction>?
        
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
        case postImagesLoaded([PostImage])
        case bookmarkImagesLoaded([PostImage])

        // 게시물 fetch
        case fetchPosts(postIds: [String])
        case fetchBookmarks

        // Navigation
        case editProfile(PresentationAction<EditProfileFeature.Action>)
        case userSearch(PresentationAction<UserSearchFeature.Action>)
        case followList(PresentationAction<FollowListFeature.Action>)
        case settingsMenu(PresentationAction<SettingsMenuAction>)

        enum SettingsMenuAction: Equatable {
            case logout
            case deleteAccount
        }
    }
    
    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    do {
                        let profile = try await NetworkManager.shared.performRequest(
                            ProfileRouter.lookupMe,
                            as: ProfileDTO.self
                        ).toDomain
                        await send(.profileLoaded(profile))
                    } catch {
                        // TODO: 에러 처리
                        print("프로필 로드 실패: \(error)")
                    }
                }
                
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
                // TODO: 게시글 작성 화면으로 이동
                return .none
                
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
                    guard state.postImages.isEmpty, let postIds = state.profile?.posts else {
                        return .none
                    }
                    return .send(.fetchPosts(postIds: postIds))
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
                return .send(.fetchPosts(postIds: profile.posts))
                
            case .postImagesLoaded(let images):
                state.postImages = images
                return .none

            case .bookmarkImagesLoaded(let images):
                state.bookmarkImages = images
                return .none

            case .fetchPosts(let postIds):
                // TODO: postIds로 게시물 데이터 fetch 후 PostImage 배열로 변환
                // return .run { send in
                //     do {
                //         let posts = try await fetchPostsByIds(postIds)
                //         let postImages = posts.map { PostImage(id: $0.id, imageURL: $0.imageURL) }
                //         await send(.postImagesLoaded(postImages))
                //     } catch {
                //         print("게시물 로드 실패: \(error)")
                //     }
                // }
                return .none
                
            case .fetchBookmarks:
                // TODO: 북마크한 게시물 데이터 fetch
                // return .run { send in
                //     do {
                //         let bookmarkedPosts = try await fetchBookmarkedPosts()
                //         let bookmarkImages = bookmarkedPosts.map { PostImage(id: $0.id, imageURL: $0.imageURL) }
                //         await send(.bookmarkImagesLoaded(bookmarkImages))
                //     } catch {
                //         print("북마크 로드 실패: \(error)")
                //     }
                // }
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
                                    print("최근 검색어 삭제 실패: \(error)")
                                }
                            }
                        }

                        // 성공 시 로그아웃 처리
                        await send(.logoutCompleted)
                    } catch {
                        // TODO: 에러 처리
                        print("회원탈퇴 실패: \(error)")
                    }
                }

            case .logout:
                // 실제 로그아웃 처리는 AppFeature에서 수행
                return .send(.logoutCompleted)

            case .logoutCompleted:
                // MainTabFeature를 통해 AppFeature로 전달되어 로그인 화면으로 전환
                return .none

            case .settingsMenu:
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

        init(id: String, imagePath: String, imageData: Data? = nil) {
            self.id = id
            self.imagePath = imagePath
            self.imageData = imageData
            self.isVideo = MediaTypeHelper.isVideoPath(imagePath)
        }
    }
}
