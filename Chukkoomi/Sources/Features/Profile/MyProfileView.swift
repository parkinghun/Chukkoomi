//
//  MyProfileView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/5/25.
//

import SwiftUI
import ComposableArchitecture

struct MyProfileView: View {
    let store: StoreOf<MyProfileFeature>
    @Environment(\.dismiss) private var dismiss

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
                if viewStore.isPresented {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            AppIcon.xmark
                                .foregroundStyle(.black)
                        }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewStore.send(.settingsButtonTapped)
                        } label: {
                            AppIcon.ellipsis
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewStore.send(.searchButtonTapped)
                        } label: {
                            AppIcon.searchUser
                        }
                    }
                }
            }
            .confirmationDialog(
                store: store.scope(state: \.$settingsMenu, action: \.settingsMenu)
            )
            .onAppear {
                viewStore.send(.onAppear)
            }
            // 네비게이션 연결
            .modifier(MyProfileNavigation(store: store))
        }
    }

    // MARK: - 프로필 헤더
    private func profileHeaderSection(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
        VStack(spacing: 0) {
            // 프로필 이미지
            if let profileImagePath = viewStore.profile?.profileImage {
                AsyncMediaImageView(
                    imagePath: profileImagePath,
                    width: 100,
                    height: 100,
                    onImageLoaded: { data in
                        viewStore.send(.profileImageLoaded(data))
                    }
                )
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay {
                        AppIcon.personFill
                            .foregroundStyle(.gray)
                            .font(.system(size: 50))
                    }
            }

            // 닉네임
            Text(viewStore.nickname)
                .font(.appMain)
                .lineLimit(1)
                .frame(height: 28)
                .padding(.top, AppPadding.medium)

            // 한줄 소개
            Text(viewStore.introduce)
                .font(.appBody)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
                .frame(height: 22)
        }
    }

    // MARK: - 통계 섹션
    private func statsSection(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
        HStack(spacing: 0) {
            statItem(title: "게시글", count: viewStore.postCount, action: nil)
            Spacer()
            statItem(title: "팔로워", count: viewStore.followerCount) {
                viewStore.send(.followerButtonTapped)
            }
            Spacer()
            statItem(title: "팔로잉", count: viewStore.followingCount) {
                viewStore.send(.followingButtonTapped)
            }
        }
    }

    private func statItem(title: String, count: Int, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: AppPadding.small / 2) {
                Text(title)
                    .font(.appCaption)
                    .foregroundStyle(AppColor.textSecondary)
                Text("\(count)")
                    .font(.appSubTitle)
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(action != nil)
    }

    // MARK: - 프로필 수정 버튼
    private func editProfileButton(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
        FillButton(title: "프로필 수정") {
            viewStore.send(.editProfileButtonTapped)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 탭 선택
    private func tabSelector(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
        HStack(spacing: 0) {
            ForEach(MyProfileFeature.State.Tab.allCases, id: \.self) { tab in
                Button {
                    viewStore.send(.tabSelected(tab))
                } label: {
                    VStack(spacing: AppPadding.small) {
                        Text(tab.rawValue)
                            .font(.appBody)
                            .fontWeight(viewStore.selectedTab == tab ? .semibold : .regular)
                            .foregroundStyle(viewStore.selectedTab == tab ? .black : AppColor.textSecondary)

                        if viewStore.selectedTab == tab {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 3)
                        } else {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 44)
    }

    // MARK: - 게시글 그리드
    private func postsGrid(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        let items = viewStore.selectedTab == .posts ? viewStore.postImages : viewStore.bookmarkImages

        return ZStack {
            if items.isEmpty && viewStore.selectedTab == .bookmarks {
                VStack(spacing: AppPadding.medium) {
                    Text("북마크한 게시글이 없습니다.")
                        .font(.appSubTitle)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(items) { image in
                            postGridItem(postImage: image, viewStore: viewStore)
                                .onAppear {
                                    viewStore.send(.postItemAppeared(image.id))
                                }
                        }

                        // 게시글 탭일 때만 추가 버튼 표시
                        if viewStore.selectedTab == .posts {
                            addPostButton(viewStore: viewStore)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func postGridItem(postImage: MyProfileFeature.PostImage, viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
        GeometryReader { geometry in
            AsyncMediaImageView(
                imagePath: postImage.imagePath,
                width: geometry.size.width,
                height: geometry.size.width
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture {
            viewStore.send(.postItemTapped(postImage.id))
        }
    }

    // MARK: - 게시글 추가 버튼
    private func addPostButton(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
        GeometryReader { geometry in
            Button {
                viewStore.send(.addPostButtonTapped)
            } label: {
                Rectangle()
                    .fill(AppColor.darkGray)
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .overlay {
                        AppIcon.plus
                            .foregroundStyle(.white)
                            .font(.system(size: 30))
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Navigation 구성
private struct MyProfileNavigation: ViewModifier {
    let store: StoreOf<MyProfileFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(
                store: store.scope(state: \.$editProfile, action: \.editProfile)
            ) { store in
                EditProfileView(store: store)
            }
            .navigationDestination(
                store: store.scope(state: \.$userSearch, action: \.userSearch)
            ) { store in
                UserSearchView(store: store)
            }
            .navigationDestination(
                store: store.scope(state: \.$followList, action: \.followList)
            ) { store in
                FollowListView(store: store)
            }
            .navigationDestination(
                store: store.scope(state: \.$postDetail, action: \.postDetail)
            ) { store in
                PostView(store: store)
            }
    }
}
