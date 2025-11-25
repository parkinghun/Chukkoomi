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
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom,AppPadding.medium)

            // 미디어 + 액션바 (가로 배치)
            HStack(alignment: .center, spacing: 0) {
                mediaContentView
                    .frame(maxWidth: .infinity)

                actionBarView
                    .padding(.leading, 4)
            }
            .padding(.bottom,AppPadding.medium)

            titleView
                .padding(.bottom,AppPadding.medium)

            // 좋아요한 사람 프로필 이미지 + 좋아요 수
            if store.likeCount > 0 {
                likedUsersView
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .confirmationDialog(
            store: store.scope(state: \.$menu, action: \.menu)
        )
        .alert(
            store: store.scope(state: \.$deleteAlert, action: \.deleteAlert)
        )
        .onAppear {
            store.send(.loadLikedUsers)
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            // 프로필 영역 (이미지 + 이름/시간)
            HStack(spacing: 12) {
                // 프로필 이미지
                if let profileImagePath = store.post.creator?.profileImage {
                    AsyncMediaImageView(
                        imagePath: profileImagePath,
                        width: 40,
                        height: 40,
                        onImageLoaded: { _ in }
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.post.creator?.nickname ?? "사용자")
                        .foregroundStyle(.black)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let createdAt = store.post.createdAt {
                        Text(timeAgoString(from: createdAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .buttonWrapper {
                store.send(.profileTapped)
            }

            Spacer()

            // 항상 메뉴 버튼 표시
            menuButtonView()
        }
    }

    // MARK: - Title
    private var titleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 해시태그 제외한 본문만 표시
            Text(extractContentWithoutHashtags(from: store.post.content))
                .font(Font.appSubBody)

            // 해시태그 표시 (버튼)
            if !store.post.hashTags.isEmpty {
                HashtagFlowLayout(spacing: 8) {
                    ForEach(store.post.hashTags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(Font.appSubBody)
                            .foregroundColor(.blue)
                            .buttonWrapper {
                                store.send(.hashtagTapped(tag))
                            }
                    }
                }
            }
        }
    }

    // MARK: - Media Content (Image or Video)
    @ViewBuilder
    private var mediaContentView: some View {
        if let firstFile = store.post.files.first {
            let isVideo = MediaTypeHelper.isVideoPath(firstFile)

            if isVideo {
                // 비디오 재생
                URLMediaPlayerView(mediaPath: firstFile)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipped()
                    .cornerRadius(12)
            } else {
                // 이미지 표시
                AsyncMediaImageView(
                    imagePath: firstFile,
                    width: 320,
                    height: 180
                )
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Action Bar (세로 배치)
    private var actionBarView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: store.isLiked ? "heart.fill" : "heart")
                .font(.system(size: 20))
                .foregroundColor(store.isLiked ? .red : .primary)
                .buttonWrapper {
                    store.send(.likeTapped)
                }

            AppIcon.comment
                .font(.system(size: 20))
                .buttonWrapper {
                    store.send(.commentTapped)
                }

            AppIcon.share
                .font(.system(size: 20))
                .buttonWrapper {
                    store.send(.shareTapped)
                }

            Image(systemName: store.isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 20))
                .foregroundColor(store.isBookmarked ? .blue : .primary)
                .buttonWrapper {
                    store.send(.bookmarkTapped)
                }
        }
        .foregroundColor(.primary)
        .padding(.vertical, 4)
    }
    
    private func followButtonView() -> some View {
        Text(store.isFollowing ? "팔로잉" : "+ 팔로우")
            .font(.appSubTitle)
            .foregroundColor(.black)
            .frame(width: 80, height: 40)
            .background(
                Capsule()
                    .fill(AppColor.lightGray)
            )
            .buttonWrapper {
                store.send(.followTapped)
            }
    }

    private func menuButtonView() -> some View {
        AppIcon.ellipsis
            .font(.system(size: 20))
            .frame(width: 40, height: 40)
            .foregroundStyle(.black)
            .rotationEffect(.degrees(90))
            .buttonWrapper {
                store.send(.menuTapped)
            }
    }

    // MARK: - Liked Users View
    private var likedUsersView: some View {
        HStack(spacing: 8) {
            // 프로필 이미지들 (겹쳐서 표시)
            ZStack(alignment: .leading) {
                ForEach(Array(store.likedUsers.prefix(3).enumerated()), id: \.offset) { index, user in
                    if let profileImagePath = user.profileImage {
                        AsyncMediaImageView(
                            imagePath: profileImagePath,
                            width: 24,
                            height: 24,
                            onImageLoaded: { _ in }
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                        )
                        .offset(x: CGFloat(index) * 16)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .offset(x: CGFloat(index) * 16)
                    }
                }
            }
            .frame(width: CGFloat(max(1, store.likedUsers.count)) * 16 + 8)
            .padding(.trailing, 4)

//            Spacer()
            // 좋아요 텍스트
            if let firstName = store.likedUsers.first?.nickname {
                if store.likeCount == 1{
                    Text("\(firstName)님이 좋아합니다.")
                        .font(.caption)
                        .foregroundColor(.primary)
                } else {
                    Text("\(firstName)님 외 \(formatLikeCount(store.likeCount - 1))명이 좋아합니다.")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            } else {
                Text("\(formatLikeCount(store.likeCount))명이 좋아요를 눌렀습니다")
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }

    // MARK: - 헬퍼 메서드

    /// 좋아요 수 포맷 (1000 -> 1k)
    private func formatLikeCount(_ count: Int) -> String {
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            if thousands.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(thousands))k"
            } else {
                return String(format: "%.1fk", thousands)
            }
        }
        return "\(count)"
    }

    /// 컨텐츠에서 해시태그를 제거하고 본문만 추출
    private func extractContentWithoutHashtags(from fullContent: String) -> String {
        // 정규식으로 해시태그 패턴 제거 (#으로 시작하고 공백이나 #이 아닌 문자들)
        let pattern = "#[^\\s#]+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return fullContent
        }

        let range = NSRange(location: 0, length: fullContent.utf16.count)
        let result = regex.stringByReplacingMatches(
            in: fullContent,
            options: [],
            range: range,
            withTemplate: ""
        )

        // 여러 개의 연속된 공백을 하나로 줄이고 양쪽 공백 제거
        return result
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 시간 포맷 헬퍼
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

// MARK: - URLMediaPlayerView
struct URLMediaPlayerView: View {
    let mediaPath: String
    @State private var player: AVPlayer?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black

            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                // 로드 실패
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    Text("동영상을 불러올 수 없습니다")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .task(id: mediaPath) {
            await loadVideo()
        }
    }

    private func loadVideo() async {
        isLoading = true

        do {
            let videoData: Data

            // TODO: picsum 테스트용 임시 코드 - 나중에 삭제
            if mediaPath.hasPrefix("http://") || mediaPath.hasPrefix("https://") {
                // 외부 URL: URLSession으로 직접 다운로드
                guard let url = URL(string: mediaPath) else {
                    isLoading = false
                    return
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                videoData = data
            } else {
                // 실제 사용 코드: 서버에서 다운로드
                videoData = try await NetworkManager.shared.download(
                    MediaRouter.getData(path: mediaPath)
                )
            }

            // 임시 파일로 저장 (AVPlayer는 URL이 필요)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")

            try videoData.write(to: tempURL)

            // AVPlayer 생성
            let playerItem = AVPlayerItem(url: tempURL)
            let avPlayer = AVPlayer(playerItem: playerItem)

            await MainActor.run {
                self.player = avPlayer
                self.isLoading = false
            }
        } catch is CancellationError {
            // Task가 취소되었을 때는 로그를 남기지 않음
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            print("동영상 로드 실패: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - HashtagFlowLayout for Hashtags
struct HashtagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = HashtagFlowLayoutResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = HashtagFlowLayoutResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            let position = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: position, proposal: .unspecified)
        }
    }

    struct HashtagFlowLayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // 다음 줄로
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))

                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(
                width: maxWidth,
                height: currentY + lineHeight
            )
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
