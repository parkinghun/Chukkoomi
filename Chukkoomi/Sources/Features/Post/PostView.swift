//
//  PostView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/5/25.
//

import SwiftUI
import ComposableArchitecture

struct PostView: View {
    let store: StoreOf<PostFeature>

    var body: some View {
        ZStack {
            if store.postCells.isEmpty && store.isLoading {
                // 초기 로딩
                ProgressView("게시글을 불러오는 중...")
            } else if store.postCells.isEmpty && !store.isLoading {
                // 빈 상태
                emptyStateView
            } else {
                // 게시글 리스트
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(
                            store.scope(state: \.postCells, action: \.postCell)
                        ) { cellStore in
                            PostCellView(store: cellStore)
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
                .refreshable {
                    store.send(.loadPosts)
                }
            }

            // 에러 메시지
            if let errorMessage = store.errorMessage {
                errorBanner(message: errorMessage)
            }
        }
        .navigationTitle(store.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(
            store: store.scope(state: \.$hashtagSearch, action: \.hashtagSearch)
        ) { store in
            PostView(store: store)
        }
        .navigationDestination(
            store: store.scope(state: \.$postCreate, action: \.postCreate)
        ) { store in
            PostCreateView(store: store)
        }
        .navigationDestination(
            store: store.scope(state: \.$myProfile, action: \.myProfile)
        ) { store in
            MyProfileView(store: store)
        }
        .navigationDestination(
            store: store.scope(state: \.$otherProfile, action: \.otherProfile)
        ) { store in
            OtherProfileView(store: store)
        }
        .sheet(
            store: store.scope(state: \.$sharePost, action: \.sharePost)
        ) { store in
            NavigationStack {
                SharePostView(store: store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(
            store: store.scope(state: \.$comment, action: \.comment)
        ) { store in
            NavigationStack {
                CommentView(store: store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            store.send(.onAppear)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("게시글이 없습니다")
                .font(.headline)
                .foregroundColor(.gray)

            Button("새로고침") {
                store.send(.loadPosts)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Error Banner
    private func errorBanner(message: String) -> some View {
        VStack {
            Spacer()

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    store.send(.loadPosts)
                } label: {
                    Text("재시도")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color.red)
            .cornerRadius(8)
            .padding()
        }
    }
}


#Preview {
    PostView(
        store: Store(
            initialState: PostFeature.State()
        ) {
            PostFeature()
        }
    )
}
