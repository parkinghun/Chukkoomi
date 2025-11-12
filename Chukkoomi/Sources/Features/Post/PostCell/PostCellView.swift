//
//  PostCellView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import SwiftUI
import ComposableArchitecture

struct PostCellView: View {
    let store: StoreOf<PostCellFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 상단: 프로필 + 팔로우 버튼
            headerView

            // 제목
            titleView

            // 이미지
            imageView

            // 하단 액션 바
            actionBarView
        }
        .padding(.vertical, 8)
        .buttonWrapper {
            store.send(.postTapped)
        }
    }

    // MARK: - Header
    private var headerView: some View {
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
                Text(store.post.creator?.nickname ?? "사용자")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let createdAt = store.post.createdAt {
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
                .buttonWrapper {
                    store.send(.followTapped)
                }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Title
    private var titleView: some View {
        Text(store.post.title)
            .font(.body)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
    }

    // MARK: - Image
    @ViewBuilder
    private var imageView: some View {
        if !store.post.files.isEmpty {
            Color.gray.opacity(0.2)
                .frame(height: 300)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                )
        }
    }

    // MARK: - Action Bar
    private var actionBarView: some View {
        HStack(spacing: 16) {
            // 좋아요
            HStack(spacing: 4) {
                Image(systemName: store.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor(store.isLiked ? .red : .primary)
                Text("\(store.post.likes?.count ?? 0)")
                    .font(.caption)
            }
            .buttonWrapper {
                store.send(.likeTapped)
            }

            // 댓글
            HStack(spacing: 4) {
                AppIcon.comment
                    .font(.system(size: 20))
                Text("\(store.post.commentCount ?? 0)")
                    .font(.caption)
            }
            .buttonWrapper {
                store.send(.commentTapped)
            }

            // 공유
            AppIcon.share
                .font(.system(size: 20))
                .buttonWrapper {
                    store.send(.shareTapped)
                }

            Spacer()

            // 북마크
            Image(systemName: store.isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 20))
                .foregroundColor(store.isBookmarked ? .blue : .primary)
                .buttonWrapper {
                    store.send(.bookmarkTapped)
                }
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 16)
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

// MARK: - Preview
#Preview {
    PostCellView(
        store: Store(
            initialState: PostCellFeature.State(
                post: Post(
                    teams: .all,
                    title: "테스트 게시글",
                    price: 0,
                    content: "내용",
                    files: ["image1"]
                )
            )
        ) {
            PostCellFeature()
        }
    )
}
