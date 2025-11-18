//
//  SearchView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import SwiftUI
import ComposableArchitecture

struct SearchView: View {
    let store: StoreOf<SearchFeature>
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 검색바 + 취소 버튼
                HStack(spacing: AppPadding.medium) {
                    SearchBar(
                        text: viewStore.binding(
                            get: \.searchText,
                            send: { .searchTextChanged($0) }
                        ),
                        isFocused: $isSearchFieldFocused,
                        placeholder: "해시태그로 검색해보세요",
                        onSubmit: {
                            isSearchFieldFocused = false
                            viewStore.send(.search)
                        },
                        onClear: {
                            viewStore.send(.clearSearch)
                        }
                    )
                    .onChange(of: isSearchFieldFocused) { _, isFocused in
                        if isFocused {
                            viewStore.send(.searchBarFocused)
                        }
                    }

                    if viewStore.isSearching {
                        Button {
                            isSearchFieldFocused = false
                            viewStore.send(.cancelButtonTapped)
                        } label: {
                            Text("취소")
                                .font(.appBody)
                                .foregroundStyle(.black)
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, AppPadding.large)
                .animation(.easeInOut(duration: 0.2), value: viewStore.isSearching)

                // 최근 검색어 또는 피드 그리드
                if viewStore.isSearching {
                    recentSearchesView(viewStore: viewStore)
                        .padding(.top, 4)
                } else {
                    feedContentView(viewStore: viewStore)
                        .padding(.top, 4)
                }
            }
            .navigationTitle("피드")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewStore.send(.onAppear)
            }
            // 네비게이션 연결
            .modifier(SearchNavigation(store: store))
        }
    }

    // MARK: - 피드 컨텐츠 뷰
    @ViewBuilder
    private func feedContentView(viewStore: ViewStoreOf<SearchFeature>) -> some View {
        if viewStore.isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewStore.posts.isEmpty {
            Spacer()
            Text("게시물이 없습니다")
                .font(.appBody)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        } else {
            feedGrid(posts: viewStore.posts, viewStore: viewStore)
        }
    }

    // MARK: - 피드 그리드
    private func feedGrid(posts: [SearchFeature.PostItem], viewStore: ViewStoreOf<SearchFeature>) -> some View {
        GeometryReader { geometry in
            let cellSize = (geometry.size.width - 8 - 8) / 3 // padding 4 * 2, spacing 4 * 2

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(0..<numberOfBlocks(for: posts.count), id: \.self) { blockIndex in
                        gridBlock(blockIndex: blockIndex, posts: posts, cellSize: cellSize, viewStore: viewStore)
                    }
                }
                .padding(4)
            }
        }
    }

    // MARK: - 그리드 블록 (패턴 반복)
    private func gridBlock(blockIndex: Int, posts: [SearchFeature.PostItem], cellSize: CGFloat, viewStore: ViewStoreOf<SearchFeature>) -> some View {
        let startIndex = blockIndex * 12
        let blockPosts = Array(posts.dropFirst(startIndex).prefix(12))

        return VStack(alignment: .leading, spacing: 4) {
            // Row 0-1: 큰 셀(왼쪽) + 작은 셀 2개(오른쪽)
            if !blockPosts.isEmpty {
                HStack(spacing: 4) {
                    if blockPosts.count > 0 {
                        postItem(post: blockPosts[0], width: cellSize * 2 + 4, height: cellSize * 2 + 4, viewStore: viewStore)
                    }

                    VStack(spacing: 4) {
                        if blockPosts.count > 1 {
                            postItem(post: blockPosts[1], width: cellSize, height: cellSize, viewStore: viewStore)
                        }
                        if blockPosts.count > 2 {
                            postItem(post: blockPosts[2], width: cellSize, height: cellSize, viewStore: viewStore)
                        }
                    }
                }
            }

            // Row 2: 작은 셀 3개
            if blockPosts.count > 3 {
                HStack(spacing: 4) {
                    if blockPosts.count > 3 {
                        postItem(post: blockPosts[3], width: cellSize, height: cellSize, viewStore: viewStore)
                    }
                    if blockPosts.count > 4 {
                        postItem(post: blockPosts[4], width: cellSize, height: cellSize, viewStore: viewStore)
                    }
                    if blockPosts.count > 5 {
                        postItem(post: blockPosts[5], width: cellSize, height: cellSize, viewStore: viewStore)
                    }
                }
            }

            // Row 3-4: 작은 셀 2개(왼쪽) + 큰 셀(오른쪽)
            if blockPosts.count > 6 {
                HStack(spacing: 4) {
                    VStack(spacing: 4) {
                        if blockPosts.count > 6 {
                            postItem(post: blockPosts[6], width: cellSize, height: cellSize, viewStore: viewStore)
                        }
                        if blockPosts.count > 7 {
                            postItem(post: blockPosts[7], width: cellSize, height: cellSize, viewStore: viewStore)
                        }
                    }

                    if blockPosts.count > 8 {
                        postItem(post: blockPosts[8], width: cellSize * 2 + 4, height: cellSize * 2 + 4, viewStore: viewStore)
                    }
                }
            }

            // Row 5: 작은 셀 3개
            if blockPosts.count > 9 {
                HStack(spacing: 4) {
                    if blockPosts.count > 9 {
                        postItem(post: blockPosts[9], width: cellSize, height: cellSize, viewStore: viewStore)
                    }
                    if blockPosts.count > 10 {
                        postItem(post: blockPosts[10], width: cellSize, height: cellSize, viewStore: viewStore)
                    }
                    if blockPosts.count > 11 {
                        postItem(post: blockPosts[11], width: cellSize, height: cellSize, viewStore: viewStore)
                    }
                }
            }
        }
    }

    // MARK: - 게시물 아이템
    private func postItem(post: SearchFeature.PostItem, width: CGFloat, height: CGFloat, viewStore: ViewStoreOf<SearchFeature>) -> some View {
        AsyncMediaImageView(
            imagePath: post.imagePath,
            width: width,
            height: height
        )
        .onTapGesture {
            viewStore.send(.postTapped(post.id))
        }
        .onAppear {
            viewStore.send(.postItemAppeared(post.id))
        }
    }

    // MARK: - 최근 검색어 뷰
    private func recentSearchesView(viewStore: ViewStoreOf<SearchFeature>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewStore.isLoadingRecentSearches {
                    VStack(spacing: AppPadding.medium) {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else if viewStore.recentSearches.isEmpty {
                    VStack(spacing: AppPadding.medium) {
                        Spacer()
                        Text("최근 검색어가 없습니다")
                            .font(.appBody)
                            .foregroundStyle(AppColor.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(viewStore.recentSearches, id: \.id) { recentWord in
                            recentSearchRow(recentWord: recentWord, viewStore: viewStore)
                        }
                    }
                    .padding(.top, AppPadding.small)
                }
            }
        }
    }

    // MARK: - 최근 검색어 행
    private func recentSearchRow(recentWord: FeedRecentWord, viewStore: ViewStoreOf<SearchFeature>) -> some View {
        HStack(spacing: AppPadding.medium) {
            Text("#")
                .font(.appBody)
                .foregroundStyle(AppColor.textSecondary)

            Text(recentWord.keyword)
                .font(.appBody)
                .foregroundStyle(.black)

            Spacer()

            Button {
                viewStore.send(.deleteRecentSearch(recentWord.keyword))
            } label: {
                AppIcon.xmark
                    .foregroundStyle(AppColor.textSecondary)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, AppPadding.large)
        .padding(.vertical, AppPadding.medium)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFieldFocused = false
            viewStore.send(.recentSearchTapped(recentWord.keyword))
        }
    }

    // MARK: - Helper
    private func numberOfBlocks(for itemCount: Int) -> Int {
        return (itemCount + 11) / 12
    }
}

// MARK: - Navigation 구성
private struct SearchNavigation: ViewModifier {
    let store: StoreOf<SearchFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(
                store: store.scope(state: \.$postDetail, action: \.postDetail)
            ) { store in
                PostView(store: store)
            }
            .navigationDestination(
                store: store.scope(state: \.$hashtagSearch, action: \.hashtagSearch)
            ) { store in
                PostView(store: store)
            }
    }
}

