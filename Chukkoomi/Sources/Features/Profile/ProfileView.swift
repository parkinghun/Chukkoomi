//
//  ProfileView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/5/25.
//

import SwiftUI
import ComposableArchitecture

struct ProfileView: View {
    let store: StoreOf<ProfileFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 프로필 상단 섹션
                profileHeaderSection(viewStore: viewStore)
                    .padding(.top, AppPadding.large)

                // 통계 섹션
                statsSection(viewStore: viewStore)
                    .padding(.top, AppPadding.large)

                // 프로필 수정 버튼
                editProfileButton(viewStore: viewStore)
                    .padding(.top, AppPadding.medium)

                // 탭 선택
                tabSelector(viewStore: viewStore)
                    .padding(.top, AppPadding.medium)

                // 그리드
                postsGrid(viewStore: viewStore)
                
            }
            .padding(.horizontal, AppPadding.large)
            .navigationTitle("프로필")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewStore.send(.searchButtonTapped)
                    } label: {
                        AppIcon.search
                    }
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }

    // MARK: - 프로필 헤더
    private func profileHeaderSection(viewStore: ViewStoreOf<ProfileFeature>) -> some View {
        VStack(spacing: AppPadding.small) {
            // 프로필 이미지
            Group {
                if let imageData = viewStore.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            AppIcon.personFill
                                .foregroundColor(.gray)
                                .font(.system(size: 40))
                        }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            // 닉네임
            Text(viewStore.nickname)
                .font(.appTitle)

            // 한줄 소개
            Text(viewStore.introduce)
                .font(.appBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 통계 섹션
    private func statsSection(viewStore: ViewStoreOf<ProfileFeature>) -> some View {
        HStack(spacing: 0) {
            statItem(title: "게시글", count: viewStore.postCount)
            Spacer()
            statItem(title: "팔로워", count: viewStore.followerCount)
            Spacer()
            statItem(title: "팔로잉", count: viewStore.followingCount)
        }
    }

    private func statItem(title: String, count: Int) -> some View {
        VStack(spacing: AppPadding.small / 2) {
            Text("\(count)")
                .font(.appSubTitle)
            Text(title)
                .font(.appCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 프로필 수정 버튼
    private func editProfileButton(viewStore: ViewStoreOf<ProfileFeature>) -> some View {
        Button {
            viewStore.send(.editProfileButtonTapped)
        } label: {
            Text("프로필 수정")
                .font(.appBody)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color.gray.opacity(0.1))
                .customRadius(.small)
        }
    }

    // MARK: - 탭 선택
    private func tabSelector(viewStore: ViewStoreOf<ProfileFeature>) -> some View {
        HStack(spacing: 0) {
            ForEach(ProfileFeature.State.Tab.allCases, id: \.self) { tab in
                Button {
                    viewStore.send(.tabSelected(tab))
                } label: {
                    VStack(spacing: AppPadding.small) {
                        Text(tab.rawValue)
                            .font(.appBody)
                            .fontWeight(viewStore.selectedTab == tab ? .semibold : .regular)
                            .foregroundColor(viewStore.selectedTab == tab ? .primary : .secondary)

                        Rectangle()
                            .fill(viewStore.selectedTab == tab ? Color.primary : Color.secondary)
                            .frame(height: viewStore.selectedTab == tab ? 3 : 0.4)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 44)
    }

    // MARK: - 게시글 그리드
    private func postsGrid(viewStore: ViewStoreOf<ProfileFeature>) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        let items = viewStore.selectedTab == .posts ? viewStore.postImages : viewStore.bookmarkImages

        return ZStack {
            if items.isEmpty {
                VStack(spacing: AppPadding.medium) {
                    Text(viewStore.selectedTab == .posts ? "게시글이 없습니다." : "북마크한 게시글이 없습니다.")
                        .font(.appBody)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(items) { image in
                            postGridItem(postImage: image)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func postGridItem(postImage: ProfileFeature.PostImage) -> some View {
        GeometryReader { geometry in
            AsyncImage(url: postImage.imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Preview
#Preview {
    let sampleProfile = Profile(
        userId: "user123",
        email: "user@example.com",
        nickname: "사용자 닉네임",
        profileImage: nil,
        introduce: "안녕하세요! 반갑습니다.",
        followers: [
            User(userId: "follower1", nickname: "팔로워1", profileImage: nil),
            User(userId: "follower2", nickname: "팔로워2", profileImage: nil)
        ],
        following: [
            User(userId: "following1", nickname: "팔로잉1", profileImage: nil)
        ],
        posts: ["post1", "post2", "post3"]
    )

    return NavigationStack {
        ProfileView(
            store: Store(
                initialState: ProfileFeature.State(
                    profile: sampleProfile,
                    postImages: [
                        .init(id: "1", imageURL: URL(string: "https://picsum.photos/200")!),
                        .init(id: "2", imageURL: URL(string: "https://picsum.photos/201")!),
                        .init(id: "3", imageURL: URL(string: "https://picsum.photos/202")!),
                        .init(id: "4", imageURL: URL(string: "https://picsum.photos/203")!),
                        .init(id: "5", imageURL: URL(string: "https://picsum.photos/204")!),
                        .init(id: "6", imageURL: URL(string: "https://picsum.photos/205")!)
                    ]
                )
            ) {
                ProfileFeature()
            }
        )
    }
}
