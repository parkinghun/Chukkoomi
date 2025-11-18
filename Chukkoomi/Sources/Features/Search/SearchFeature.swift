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

        @PresentationState var postCell: PostCellFeature.State?
    }
    
    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case searchTextChanged(String)
        case search
        case clearSearch
        case postsLoaded([PostItem])
        case postTapped(String)
        case postLoaded(Post)
        case searchBarFocused
        case cancelButtonTapped
        case recentSearchTapped(String)
        case deleteRecentSearch(String)
        case recentSearchesLoaded([FeedRecentWord])
        case postCell(PresentationAction<PostCellFeature.Action>)
    }
    
    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    do {
                        // LocationQuery의 모든 프로퍼티를 nil로 설정
                        let query = PostRouter.LocationQuery(
                            category: nil,
                            longitude: nil,
                            latitude: nil,
                            maxDistance: nil,
                            orderBy: nil,
                            sortBy: nil
                        )
                        
                        let response = try await PostService.shared.fetchPostsByLocation(query: query)
                        
                        // PostResponseDTO를 PostItem으로 변환
                        let posts = response.data.compactMap { dto -> PostItem? in
                            guard let firstFile = dto.files.first else { return nil }
                            return PostItem(id: dto.postId, imagePath: firstFile)
                        }

                        await send(.postsLoaded(posts))
                    } catch {
                        print("Failed to load posts: \(error)")
                        await send(.postsLoaded([]))
                    }
                }
                
            case .searchTextChanged(let text):
                state.searchText = text
                return .none
                
            case .search:
                guard !state.searchText.isEmpty else {
                    return .none
                }
                
                let trimmedKeyword = state.searchText.trimmingCharacters(in: .whitespaces)
                
                // TODO: 검색 결과 화면으로 이동
                
                
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
                
            case .postsLoaded(let posts):
                state.posts = posts
                state.isLoading = false
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
                        print("❌ 게시글 단건 조회 실패: \(error)")
                    }
                }

            case let .postLoaded(post):
                state.postCell = PostCellFeature.State(post: post)
                return .none

            case .postCell:
                return .none
            }
        }
        .ifLet(\.$postCell, action: \.postCell) {
            PostCellFeature()
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

