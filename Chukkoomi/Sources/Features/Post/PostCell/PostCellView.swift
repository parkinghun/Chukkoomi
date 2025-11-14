//
//  PostCellView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import SwiftUI
import ComposableArchitecture
import AVKit

struct PostCellView: View {
    let store: StoreOf<PostCellFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

            titleView

            mediaContentView

            
            actionBarView
        }
        .padding(.vertical, 8)
//        .buttonWrapper {
//            store.send(.postTapped)
//        }
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
            followButtonView()
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

    // MARK: - Media Content (Image or Video)
    @ViewBuilder
    private var mediaContentView: some View {
        if let firstFile = store.post.files.first {
            let fullURL = firstFile.toFullMediaURL
            let mediaType = MediaTypeHelper.detectMediaType(from: firstFile)

            let _ = print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            let _ = print("🎬 원본 파일 경로: \(firstFile)")
            let _ = print("🌐 생성된 전체 URL: \(fullURL)")
            let _ = print("🎨 감지된 미디어 타입: \(mediaType)")
            let _ = print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            switch mediaType {
            case .image:
                // 이미지 렌더링
                AsyncImage(url: URL(string: fullURL)) { phase in
                    switch phase {
                    case .empty:
                        // 로딩 중
                        Color.gray.opacity(0.2)
                            .frame(height: 300)
                            .overlay(
                                VStack(spacing: 8) {
                                    ProgressView()
                                    Text("이미지 로딩 중...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            )
                            .onAppear {
                                print("⏳ 이미지 로딩 시작: \(fullURL)")
                            }

                    case .success(let image):
                        // 이미지 로드 성공
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 300)
                            .clipped()
                            .onAppear {
                                print("✅ 이미지 로딩 성공: \(fullURL)")
                            }

                    case .failure(let error):
                        // 이미지 로드 실패
                        Color.gray.opacity(0.2)
                            .frame(height: 300)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("이미지를 불러올 수 없습니다")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            )
                            .onAppear {
                                print("❌ 이미지 로딩 실패")
                                print("   URL: \(fullURL)")
                                print("   에러: \(error.localizedDescription)")
                            }

                    @unknown default:
                        EmptyView()
                    }
                }

            case .video:
                // 동영상 렌더링
                if let url = URL(string: fullURL) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 300)
                        .background(Color.black)
                        .onAppear {
                            print("🎥 동영상 로딩: \(fullURL)")
                        }
                } else {
                    // URL 생성 실패
                    Color.gray.opacity(0.2)
                        .frame(height: 300)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("동영상을 불러올 수 없습니다")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(fullURL)
                                    .font(.system(size: 8))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        )
                        .onAppear {
                            print("❌ 동영상 URL 생성 실패: \(fullURL)")
                        }
                }

            case .unknown:
                // 알 수 없는 파일 형식
                Color.gray.opacity(0.2)
                    .frame(height: 300)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "doc")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("지원하지 않는 파일 형식입니다")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(firstFile)
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    )
                    .onAppear {
                        print("⚠️ 알 수 없는 파일 형식: \(firstFile)")
                    }
            }
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
    
    private func followButtonView() -> some View {
        Text("+ 팔로우")
            .font(.caption)
            .foregroundColor(.black)
            .frame(width: 80, height: 40)
            .background(
                Capsule()
                .fill(.gray)
            )
            .buttonWrapper {
                store.send(.followTapped)
            }
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
