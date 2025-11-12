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
                // 검색바
                SearchBar(
                    text: viewStore.binding(
                        get: \.searchText,
                        send: { .searchTextChanged($0) }
                    ),
                    isFocused: $isSearchFieldFocused,
                    placeholder: "검색",
                    onSubmit: {
                        viewStore.send(.search)
                    },
                    onClear: {
                        viewStore.send(.clearSearch)
                    }
                )
                .padding(.horizontal, AppPadding.large)

                // 피드 그리드
                feedContentView(viewStore: viewStore)
                    .padding(.top, 4)
            }
            .navigationTitle("피드")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewStore.send(.onAppear)
            }
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
                .foregroundColor(.secondary)
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
                            .onAppear {
                                // 마지막 블록이 나타나면 다음 페이지 로드
                                if blockIndex == numberOfBlocks(for: posts.count) - 1 {
                                    viewStore.send(.loadMorePosts)
                                }
                            }
                    }

                    // 더 로딩 중일 때 로딩 인디케이터 표시
                    if viewStore.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, AppPadding.medium)
                    }
                }
                .padding(4)
            }
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    isSearchFieldFocused = false
                }
            )
        }
    }

    // MARK: - 그리드 블록 (패턴 반복)
    private func gridBlock(blockIndex: Int, posts: [SearchFeature.PostItem], cellSize: CGFloat, viewStore: ViewStoreOf<SearchFeature>) -> some View {
        let startIndex = blockIndex * 12
        let blockPosts = Array(posts.dropFirst(startIndex).prefix(12))

        return VStack(spacing: 4) {
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
    }

    // MARK: - Helper
    private func numberOfBlocks(for itemCount: Int) -> Int {
        return (itemCount + 11) / 12
    }
}
