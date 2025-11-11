//
//  MyProfileFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

import ComposableArchitecture
import Foundation

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
        
        @PresentationState var editProfile: EditProfileFeature.State?
        @PresentationState var userSearch: UserSearchFeature.State?
        
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
        
        // API 응답
        case profileLoaded(Profile)
        case postImagesLoaded([PostImage])
        case bookmarkImagesLoaded([PostImage])
        case profileImageLoaded(Data)
        case postImageDownloaded(id: String, data: Data)
        case bookmarkImageDownloaded(id: String, data: Data)
        
        // 게시물 fetch
        case fetchPosts(postIds: [String])
        case fetchBookmarks
        case fetchProfileImage(path: String)
        case fetchPostImage(id: String, path: String)
        case fetchBookmarkImage(id: String, path: String)
        
        // Navigation
        case editProfile(PresentationAction<EditProfileFeature.Action>)
        case userSearch(PresentationAction<UserSearchFeature.Action>)
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
                // 프로필 이미지와 게시물 fetch
                if let imagePath = profile.profileImage {
                    return .merge(
                        .send(.fetchProfileImage(path: imagePath)),
                        .send(.fetchPosts(postIds: profile.posts))
                    )
                } else {
                    return .send(.fetchPosts(postIds: profile.posts))
                }
                
            case .postImagesLoaded(let images):
                state.postImages = images
                // 각 이미지 다운로드
                let effects = images.map { image in
                    Effect<Action>.send(.fetchPostImage(id: image.id, path: image.imagePath))
                }
                return .merge(effects)
                
            case .bookmarkImagesLoaded(let images):
                state.bookmarkImages = images
                // 각 이미지 다운로드
                let effects = images.map { image in
                    Effect<Action>.send(.fetchBookmarkImage(id: image.id, path: image.imagePath))
                }
                return .merge(effects)
                
            case .profileImageLoaded(let data):
                state.profileImageData = data
                return .none
                
            case .postImageDownloaded(let id, let data):
                if let index = state.postImages.firstIndex(where: { $0.id == id }) {
                    state.postImages[index].imageData = data
                }
                return .none
                
            case .bookmarkImageDownloaded(let id, let data):
                if let index = state.bookmarkImages.firstIndex(where: { $0.id == id }) {
                    state.bookmarkImages[index].imageData = data
                }
                return .none
                
            case .fetchProfileImage(let path):
                return .run { send in
                    do {
                        let imageData = try await NetworkManager.shared.download(
                            MediaRouter.getData(path: path)
                        )
                        await send(.profileImageLoaded(imageData))
                    } catch {
                        print("프로필 이미지 로드 실패: \(error)")
                    }
                }
                
            case .fetchPostImage(let id, let path):
                return .run { send in
                    do {
                        let imageData = try await NetworkManager.shared.download(
                            MediaRouter.getData(path: path)
                        )
                        await send(.postImageDownloaded(id: id, data: imageData))
                    } catch {
                        print("게시글 이미지 로드 실패: \(error)")
                    }
                }
                
            case .fetchBookmarkImage(let id, let path):
                return .run { send in
                    do {
                        let imageData = try await NetworkManager.shared.download(
                            MediaRouter.getData(path: path)
                        )
                        await send(.bookmarkImageDownloaded(id: id, data: imageData))
                    } catch {
                        print("북마크 이미지 로드 실패: \(error)")
                    }
                }
                
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
                if let imagePath = updatedProfile.profileImage {
                    return .send(.fetchProfileImage(path: imagePath))
                }
                return .none
                
            case .editProfile:
                return .none
                
            case .userSearch:
                return .none
            }
        }
        .ifLet(\.$editProfile, action: \.editProfile) {
            EditProfileFeature()
        }
        .ifLet(\.$userSearch, action: \.userSearch) {
            UserSearchFeature()
        }
    }
}

// MARK: - Models
extension MyProfileFeature {
    // 게시글 그리드에 표시할 이미지 정보
    struct PostImage: Equatable, Identifiable {
        let id: String
        let imagePath: String
        var imageData: Data?
    }
}
