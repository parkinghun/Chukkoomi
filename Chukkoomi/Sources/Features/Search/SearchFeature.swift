//
//  SearchFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import ComposableArchitecture
import Foundation
import RealmSwift

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
        var recentSearches: [FeedRecentWord] = []
        var isLoadingRecentSearches: Bool = false

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
        case recentSearchesLoaded([FeedRecentWord])
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

                let trimmedKeyword = state.searchText.trimmingCharacters(in: .whitespaces)

                // 검색 결과 화면으로 이동
                state.searchResult = SearchResultFeature.State(searchQuery: state.searchText)

                // Realm에 최근 검색어 저장
                return .run { send in
                    await MainActor.run {
                        do {
                            guard let userId = UserDefaultsHelper.userId else { return }

                            let realm = try Realm()

                            // 기존에 같은 키워드가 있으면 삭제 (현재 사용자만)
                            if let existingWord = realm.objects(FeedRecentWordDTO.self)
                                .filter("userId == %@ AND keyword == %@", userId, trimmedKeyword)
                                .first {
                                try realm.write {
                                    realm.delete(existingWord)
                                }
                            }

                            // 새로운 검색어 추가
                            let newWord = FeedRecentWordDTO(userId: userId, keyword: trimmedKeyword, searchedAt: Date())
                            try realm.write {
                                realm.add(newWord)
                            }

                            // 최근 검색어 목록 갱신 (현재 사용자만)
                            let recentWordDTOs = realm.objects(FeedRecentWordDTO.self)
                                .filter("userId == %@", userId)
                                .sorted(byKeyPath: "searchedAt", ascending: false)
                            let recentWords = Array(recentWordDTOs.prefix(10).map { $0.toDomain })

                            Task {
                                send(.recentSearchesLoaded(recentWords))
                            }

                            // TODO: 실제 검색 API 호출
                        } catch {
                            print("최근 검색어 저장 실패: \(error)")
                        }
                    }
                }

            case .clearSearch:
                state.searchText = ""
                return .none

            case .searchBarFocused:
                state.isSearching = true
                state.isLoadingRecentSearches = true

                // Realm에서 최근 검색어 불러오기
                return .run { send in
                    await MainActor.run {
                        do {
                            guard let userId = UserDefaultsHelper.userId else {
                                send(.recentSearchesLoaded([]))
                                return
                            }

                            let realm = try Realm()
                            let recentWordDTOs = realm.objects(FeedRecentWordDTO.self)
                                .filter("userId == %@", userId)
                                .sorted(byKeyPath: "searchedAt", ascending: false)

                            let recentWords = Array(recentWordDTOs.prefix(10).map { $0.toDomain })
                            Task {
                                send(.recentSearchesLoaded(recentWords))
                            }
                        } catch {
                            print("최근 검색어 불러오기 실패: \(error)")
                        }
                    }
                }

            case .cancelButtonTapped:
                state.isSearching = false
                state.searchText = ""
                return .none

            case .recentSearchTapped(let searchText):
                state.searchText = searchText
                return .send(.search)

            case .deleteRecentSearch(let searchText):
                // Realm에서 최근 검색어 삭제 후 다시 불러오기
                return .run { send in
                    await MainActor.run {
                        do {
                            guard let userId = UserDefaultsHelper.userId else { return }

                            let realm = try Realm()
                            if let wordToDelete = realm.objects(FeedRecentWordDTO.self)
                                .filter("userId == %@ AND keyword == %@", userId, searchText)
                                .first {
                                try realm.write {
                                    realm.delete(wordToDelete)
                                }
                            }

                            // 삭제 후 최신 10개 다시 불러오기 (현재 사용자만)
                            let recentWordDTOs = realm.objects(FeedRecentWordDTO.self)
                                .filter("userId == %@", userId)
                                .sorted(byKeyPath: "searchedAt", ascending: false)
                            let recentWords = Array(recentWordDTOs.prefix(10).map { $0.toDomain })

                            Task {
                                send(.recentSearchesLoaded(recentWords))
                            }
                        } catch {
                            print("최근 검색어 삭제 실패: \(error)")
                        }
                    }
                }

            case .recentSearchesLoaded(let recentWords):
                state.recentSearches = recentWords
                state.isLoadingRecentSearches = false
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
