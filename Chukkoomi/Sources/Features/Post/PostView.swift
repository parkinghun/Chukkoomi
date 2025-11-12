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
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewStore.posts, id: \.id) { post in
                            postCellView(post: post, viewStore: viewStore)

                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
                .navigationTitle("게시글")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    viewStore.send(.onAppear)
                }
            }
        }
    }

    // MARK: - Helper
    private func postCellView(post: Post, viewStore: ViewStoreOf<PostFeature>) -> some View {
        PostCell(
            post: post,
            onLikeTap: {
                if let id = post.id {
                    viewStore.send(.likeTapped(id))
                }
            },
            onCommentTap: {
                if let id = post.id {
                    viewStore.send(.commentTapped(id))
                }
            },
            onShareTap: {
                if let id = post.id {
                    viewStore.send(.shareTapped(id))
                }
            },
            onFollowTap: {
                if let userId = post.creator?.userId {
                    viewStore.send(.followTapped(userId))
                }
            }
        )
        .buttonWrapper {
            if let id = post.id {
                viewStore.send(.postTapped(id))
            }
        }
    }
}

// MARK: - 게시물 셀
struct PostCell: View {
    let post: Post
    let onLikeTap: () -> Void
    let onCommentTap: () -> Void
    let onShareTap: () -> Void
    let onFollowTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 상단: 프로필 + 팔로우 버튼
            HStack(spacing: 12) {
                // 프로필 이미지
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.creator?.nickname ?? "사용자")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let createdAt = post.createdAt {
                        Text(timeAgoString(from: createdAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // 팔로우 버튼
                Text("+ 팔로우")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .buttonWrapper(action: onFollowTap)
            }
            .padding(.horizontal, 16)

            // 제목
            Text(post.title)
                .font(.body)
                .fontWeight(.medium)
                .padding(.horizontal, 16)

            // 이미지
            if !post.files.isEmpty {
                Color.gray.opacity(0.2)
                    .frame(height: 300)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    )
            }

            // 하단 액션 바
            HStack(spacing: 16) {
                // 좋아요
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.system(size: 20))
                    Text("\(post.likes?.count ?? 0)")
                        .font(.caption)
                }
                .buttonWrapper(action: onLikeTap)

                // 댓글
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis.message")
                        .font(.system(size: 20))
                    Text("\(post.commentCount ?? 0)")
                        .font(.caption)
                }
                .buttonWrapper(action: onCommentTap)

                // 공유
                Image(systemName: "paperplane")
                    .font(.system(size: 20))
                    .buttonWrapper(action: onShareTap)

                Spacer()

                // 북마크
                Image(systemName: "bookmark")
                    .font(.system(size: 20))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    // MARK: - 시간 포맷 헬퍼
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let day = components.day, day > 0 {
            return "\(day)일전"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)시간전"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)분전"
        } else {
            return "방금"
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
