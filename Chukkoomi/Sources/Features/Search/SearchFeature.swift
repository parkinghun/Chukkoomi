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
        var isSearching: Bool = false
        var recentSearches: [FeedRecentWord] = []
        var isLoadingRecentSearches: Bool = false

        // Pagination
        var nextCursor: String? = nil
        var isLoadingNextPage: Bool = false

        @PresentationState var postDetail: PostFeature.State?
        @PresentationState var hashtagSearch: PostFeature.State?
        @PresentationState var alert: AlertState<Action.Alert>?
    }
    
    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case searchTextChanged(String)
        case search
        case clearSearch
        case postsLoaded([PostItem], String?)
        case loadNextPage
        case nextPageLoaded([PostItem], String?)
        case postTapped(String)
        case postLoaded(Post)
        case searchBarFocused
        case cancelButtonTapped
        case recentSearchTapped(String)
        case deleteRecentSearch(String)
        case recentSearchesLoaded([FeedRecentWord])
        case postItemAppeared(String)
        case postDetail(PresentationAction<PostFeature.Action>)
        case hashtagSearch(PresentationAction<PostFeature.Action>)
        case postsLoadFailed
        case nextPageLoadFailed
        case postLoadFailed
        case alert(PresentationAction<Alert>)

        enum Alert: Equatable {}
    }
    
    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                // 초기 목록은 fetchPosts (limit = 12)
                return .run { send in
                    do {
                        let query = PostRouter.ListQuery(next: nil, limit: 12, category: FootballTeams.teamsForHeader)
                        let response = try await PostService.shared.fetchPosts(query: query)

                        let posts = response.data.compactMap { dto -> PostItem? in
                            let post = dto.toDomain
                            guard post.files.count >= 2 else { return nil }
                            let thumbnailPath = post.files[1] // 썸네일
                            let originalPath = post.files[0] // 원본
                            let isVideo = MediaTypeHelper.isVideoPath(originalPath)
                            return PostItem(id: post.id, imagePath: thumbnailPath, isVideo: isVideo)
                        }

                        await send(.postsLoaded(posts, response.nextCursor))
                    } catch {
                        print("Failed to load posts: \(error)")
                        await send(.postsLoadFailed)
                    }
                }
                
            case .searchTextChanged(let text):
                state.searchText = text
                return .none
                
            case .search:
                // 입력 정규화: 앞의 # 제거, 공백 제거
                let trimmed = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                let normalized = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
                guard !normalized.isEmpty else { return .none }

                // 해시태그 검색 화면으로 push
                state.hashtagSearch = PostFeature.State(searchHashtag: normalized)

                // Realm에 최근 검색어 저장
                let keywordToSave = normalized
                return .run { send in
                    await MainActor.run {
                        do {
                            guard let userId = UserDefaultsHelper.userId else { return }
                            
                            let realm = try Realm()
                            
                            // 기존에 같은 키워드가 있으면 삭제 (현재 사용자만)
                            if let existingWord = realm.objects(FeedRecentWordDTO.self)
                                .filter("userId == %@ AND keyword == %@", userId, keywordToSave)
                                .first {
                                try realm.write {
                                    realm.delete(existingWord)
                                }
                            }
                            
                            // 새로운 검색어 추가
                            let newWord = FeedRecentWordDTO(userId: userId, keyword: keywordToSave, searchedAt: Date())
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
                
            case .postsLoaded(let posts, let nextCursor):
                state.posts = posts
                state.nextCursor = nextCursor
                state.isLoading = false
                return .none

            case .loadNextPage:
                guard !state.isLoadingNextPage,
                      let next = state.nextCursor,
                      !next.isEmpty,
                      next != "0" // "0"이면 더 이상 불러오지 않음
                else {
                    return .none
                }
                state.isLoadingNextPage = true
                return .run { send in
                    do {
                        let query = PostRouter.ListQuery(next: next, limit: 12, category: FootballTeams.teamsForHeader)
                        let response = try await PostService.shared.fetchPosts(query: query)

                        let posts = response.data.compactMap { dto -> PostItem? in
                            let post = dto.toDomain
                            guard post.files.count >= 2 else { return nil }
                            let thumbnailPath = post.files[1] // 썸네일
                            let originalPath = post.files[0] // 원본
                            let isVideo = MediaTypeHelper.isVideoPath(originalPath)
                            return PostItem(id: post.id, imagePath: thumbnailPath, isVideo: isVideo)
                        }

                        await send(.nextPageLoaded(posts, response.nextCursor))
                    } catch {
                        await send(.nextPageLoadFailed)
                    }
                }

            case .nextPageLoaded(let newPosts, let nextCursor):
                state.posts.append(contentsOf: newPosts)
                state.nextCursor = nextCursor
                state.isLoadingNextPage = false
                return .none

            case .postItemAppeared(let id):
                // 마지막 셀이 화면에 나타났을 때만 다음 페이지 로드 트리거
                if let index = state.posts.firstIndex(where: { $0.id == id }),
                   index == state.posts.count - 1 {
                    return .send(.loadNextPage)
                }
                return .none
                
            case let .postTapped(postId):
                // 단건 조회 후 PostCell push
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

            case let .postLoaded(post):
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

            case .hashtagSearch:
                return .none

            case .postsLoadFailed:
                state.isLoading = false
                state.alert = AlertState {
                    TextState("게시글 로드 실패")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState("게시글을 불러오는데 실패했습니다.\n다시 시도해주세요.")
                }
                return .none

            case .nextPageLoadFailed:
                state.isLoadingNextPage = false
                state.alert = AlertState {
                    TextState("게시글 로드 실패")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState("추가 게시글을 불러오는데 실패했습니다.")
                }
                return .none

            case .postLoadFailed:
                state.alert = AlertState {
                    TextState("게시글 조회 실패")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState("게시글을 불러오는데 실패했습니다.\n다시 시도해주세요.")
                }
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$postDetail, action: \.postDetail) {
            PostFeature()
        }
        .ifLet(\.$hashtagSearch, action: \.hashtagSearch) {
            PostFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

// MARK: - Models
extension SearchFeature {
    struct PostItem: Equatable, Identifiable {
        let id: String
        let imagePath: String
        let isVideo: Bool

        init(id: String, imagePath: String, isVideo: Bool = false) {
            self.id = id
            self.imagePath = imagePath
            self.isVideo = isVideo
        }
    }
}

