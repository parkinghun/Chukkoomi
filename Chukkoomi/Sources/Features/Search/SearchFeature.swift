//
//  SearchFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SearchFeature {

    // MARK: - State
    struct State: Equatable {
        var searchText: String = ""
        var posts: [PostItem] = []
        var isLoading: Bool = false
        var isLoadingMore: Bool = false
        var cursor: String? = nil
        var hasMorePages: Bool = true
        var isSearching: Bool = false
        var recentSearches: [String] = []

        @PresentationState var searchResult: SearchResultFeature.State?
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case searchTextChanged(String)
        case search
        case clearSearch
        case postsLoaded([PostItem], nextCursor: String?, hasMore: Bool)
        case postTapped(String)
        case loadMorePosts
        case searchBarFocused
        case cancelButtonTapped
        case recentSearchTapped(String)
        case deleteRecentSearch(String)
        case searchResult(PresentationAction<SearchResultFeature.Action>)
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                // 첫 페이지 로드
                return .run { send in
                    // 임시 picsum 이미지 데이터 생성 (첫 페이지: 1-12)
                    let dummyPosts = (1...12).map { index in
                        PostItem(id: "\(index)", imagePath: "https://picsum.photos/400/400?random=\(index)")
                    }
                    await send(.postsLoaded(dummyPosts, nextCursor: "12", hasMore: true))
                }

            case .searchTextChanged(let text):
                state.searchText = text
                return .none

            case .search:
                guard !state.searchText.isEmpty else {
                    return .none
                }

                // TODO: Realm을 사용해서 최근 검색어 저장

                // 검색 결과 화면으로 이동
                state.searchResult = SearchResultFeature.State(searchQuery: state.searchText)

                // TODO: 실제 검색 API 호출
                return .none

            case .clearSearch:
                state.searchText = ""
                return .none

            case .searchBarFocused:
                state.isSearching = true
                // TODO: Realm에서 최근 검색어 불러오기
                return .none

            case .cancelButtonTapped:
                state.isSearching = false
                state.searchText = ""
                return .none

            case .recentSearchTapped(let searchText):
                state.searchText = searchText
                return .send(.search)

            case .deleteRecentSearch(let searchText):
                // TODO: Realm에서 최근 검색어 삭제
                state.recentSearches.removeAll { $0 == searchText }
                return .none

            case .postsLoaded(let posts, let nextCursor, let hasMore):
                state.posts.append(contentsOf: posts)
                state.cursor = nextCursor
                state.hasMorePages = hasMore
                state.isLoading = false
                state.isLoadingMore = false
                return .none

            case .loadMorePosts:
                // 이미 로딩 중이거나 더 이상 페이지가 없으면 무시
                guard !state.isLoadingMore && state.hasMorePages else {
                    return .none
                }

                state.isLoadingMore = true

                return .run { [cursor = state.cursor] send in
                    // cursor를 숫자로 변환해서 다음 12개 로드
                    let startIndex = Int(cursor ?? "0") ?? 0
                    let nextIndex = startIndex + 1
                    let endIndex = startIndex + 12

                    let dummyPosts = (nextIndex...endIndex).map { index in
                        PostItem(id: "\(index)", imagePath: "https://picsum.photos/400/400?random=\(index)")
                    }

                    // 100개까지만 로드하는 것으로 제한
                    let hasMore = endIndex < 100
                    let newCursor = hasMore ? "\(endIndex)" : nil

                    await send(.postsLoaded(dummyPosts, nextCursor: newCursor, hasMore: hasMore))
                }

            case .postTapped:
                // TODO: 게시물 상세 화면으로 이동
                return .none

            case .searchResult:
                return .none
            }
        }
        .ifLet(\.$searchResult, action: \.searchResult) {
            SearchResultFeature()
        }
    }
}

// TODO: 삭제
// MARK: - 검색 결과 Feature (임시)
@Reducer
struct SearchResultFeature {
    struct State: Equatable {
        var searchQuery: String
    }

    enum Action: Equatable {
        case onAppear
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // TODO: 검색 결과 로드
                return .none
            }
        }
    }
}

// MARK: - Models
extension SearchFeature {
    struct PostItem: Equatable, Identifiable {
        let id: String
        let imagePath: String
        let isVideo: Bool

        init(id: String, imagePath: String) {
            self.id = id
            self.imagePath = imagePath
            self.isVideo = MediaTypeHelper.isVideoPath(imagePath)
        }
    }
}
