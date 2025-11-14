//
//  OtherProfileView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

import SwiftUI
import ComposableArchitecture

struct OtherProfileView: View {
    let store: StoreOf<OtherProfileFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 프로필 상단 섹션
                profileHeaderSection(viewStore: viewStore)
                    .padding(.top, AppPadding.large)

                // 통계 섹션
                statsSection(viewStore: viewStore)
                    .padding(.top, AppPadding.large)
                
                // 팔로우, 메시지 버튼
                actionButtons(viewStore: viewStore)
                    .padding(.top, AppPadding.large)

                Divider()
                    .padding(.top, AppPadding.large)
                
                // 그리드
                postsGrid(viewStore: viewStore)
                    .padding(.top, AppPadding.small)

            }
            .padding(.horizontal, AppPadding.large)
            .navigationTitle("프로필")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewStore.send(.onAppear)
            }
            // 네비게이션 연결
            .modifier(OtherProfileNavigation(store: store))
        }
    }

    // MARK: - 프로필 헤더
    private func profileHeaderSection(viewStore: ViewStoreOf<OtherProfileFeature>) -> some View {
        VStack(spacing: 0) {
            // 프로필 이미지
            if let profileImagePath = viewStore.profile?.profileImage {
                AsyncMediaImageView(
                    imagePath: profileImagePath,
                    width: 100,
                    height: 100
                )
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay {
                        AppIcon.personFill
                            .foregroundColor(.gray)
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
                .foregroundColor(AppColor.textSecondary)
                .lineLimit(1)
                .frame(height: 22)
        }
    }

    // MARK: - 통계 섹션
    private func statsSection(viewStore: ViewStoreOf<OtherProfileFeature>) -> some View {
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
                    .foregroundColor(AppColor.textSecondary)
                Text("\(count)")
                    .font(.appSubTitle)
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(action != nil)
    }
    
    // MARK: - 액션 버튼
    private func actionButtons(viewStore: ViewStoreOf<OtherProfileFeature>) -> some View {
        HStack(spacing: AppPadding.large) {
            // 팔로우 버튼
            if viewStore.isFollowing {
                BorderButton(title: "팔로잉") {
                    viewStore.send(.followButtonTapped)
                }
            } else {
                FillButton(title: "팔로우") {
                    viewStore.send(.followButtonTapped)
                }
            }

            // 메세지 버튼
            BorderButton(title: "메세지") {
                viewStore.send(.messageButtonTapped)
            }
        }
    }

    // MARK: - 게시글 그리드
    private func postsGrid(viewStore: ViewStoreOf<OtherProfileFeature>) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        return ZStack {
            if viewStore.postImages.isEmpty {
                VStack(spacing: AppPadding.medium) {
                    Text("게시글이 없습니다.")
                        .font(.appSubTitle)
                        .foregroundColor(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(viewStore.postImages) { image in
                            postGridItem(postImage: image)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func postGridItem(postImage: OtherProfileFeature.PostImage) -> some View {
        GeometryReader { geometry in
            AsyncMediaImageView(
                imagePath: postImage.imagePath,
                width: geometry.size.width,
                height: geometry.size.width
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Navigation 구성
private struct OtherProfileNavigation: ViewModifier {
    let store: StoreOf<OtherProfileFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(
                store: store.scope(state: \.$followList, action: \.followList)
            ) { store in
                FollowListView(store: store)
            }
    }
}
