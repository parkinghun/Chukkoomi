//
//  ProfileFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

import ComposableArchitecture
import Foundation

struct ProfileFeature: Reducer {

    // MARK: - State
    struct State: Equatable {
        var profile: Profile?
        var selectedTab: Tab = .posts
        var postImages: [PostImage] = []
        var bookmarkImages: [PostImage] = []
        var isLoading: Bool = false

        // Computed properties
        var profileImageURL: URL? {
            guard let urlString = profile?.profileImage else { return nil }
            return URL(string: urlString)
        }

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
        case tabSelected(State.Tab)
        case profileLoaded(Profile)
        case postImagesLoaded([PostImage])
        case bookmarkImagesLoaded([PostImage])
    }

    // MARK: - Reducer
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isLoading = true
            // TODO: API 호출로 프로필 데이터 로드
            return .none

        case .searchButtonTapped:
            // TODO: 검색 화면으로 이동
            return .none

        case .editProfileButtonTapped:
            // TODO: 프로필 수정 화면으로 이동
            return .none

        case .tabSelected(let tab):
            state.selectedTab = tab
            return .none

        case .profileLoaded(let profile):
            state.profile = profile
            state.isLoading = false
            return .none

        case .postImagesLoaded(let images):
            state.postImages = images
            return .none

        case .bookmarkImagesLoaded(let images):
            state.bookmarkImages = images
            return .none
        }
    }
}

// MARK: - Models
extension ProfileFeature {
    // 게시글 그리드에 표시할 이미지 정보
    struct PostImage: Equatable, Identifiable {
        let id: String
        let imageURL: URL
    }
}
