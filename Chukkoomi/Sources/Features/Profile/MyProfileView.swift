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
                        AppIcon.searchUser
                    }
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }

    // MARK: - 프로필 헤더
    private func profileHeaderSection(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
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
    private func statsSection(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
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
    private func editProfileButton(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
        Button {
            viewStore.send(.editProfileButtonTapped)
        } label: {
            Text("프로필 수정")
                .font(.appBody)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(AppColor.primary)
                .customRadius(.small)
        }
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
                            .foregroundColor(viewStore.selectedTab == tab ? .primary : .secondary)

                        if viewStore.selectedTab == tab {
                            Rectangle()
                                .fill(Color.primary)
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
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(items) { image in
                            postGridItem(postImage: image)
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

    private func postGridItem(postImage: MyProfileFeature.PostImage) -> some View {
        GeometryReader { geometry in
            Group {
                if let imageData = postImage.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .overlay {
                            ProgressView()
                        }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - 게시글 추가 버튼
    private func addPostButton(viewStore: ViewStoreOf<MyProfileFeature>) -> some View {
        GeometryReader { geometry in
            Button {
                viewStore.send(.addPostButtonTapped)
            } label: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .overlay {
                        AppIcon.plus
                            .foregroundColor(.white)
                            .font(.system(size: 30))
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Preview
//#Preview {
//    return NavigationStack {
//        MyProfileView(
//            store: Store(
//                initialState: MyProfileFeature.State()
//            ) {
//                MyProfileFeature()
//            }
//        )
//    }
//}
