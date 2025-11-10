//
//  OtherProfileView.swift
//  Chukkoomi
//
//  Created by Claude on 11/7/25.
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
        }
    }

    // MARK: - 프로필 헤더
    private func profileHeaderSection(viewStore: ViewStoreOf<OtherProfileFeature>) -> some View {
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

    // MARK: - 액션 버튼
    private func actionButtons(viewStore: ViewStoreOf<OtherProfileFeature>) -> some View {
        HStack(spacing: AppPadding.large) {
            // 팔로우 버튼
            Button {
                viewStore.send(.followButtonTapped)
            } label: {
                Text(viewStore.isFollowing ? "팔로잉" : "팔로우")
                    .font(.appBody)
                    .foregroundColor(viewStore.isFollowing ? .primary : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(viewStore.isFollowing ? .clear : AppColor.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.small.rawValue)
                            .stroke(viewStore.isFollowing ? AppColor.divider : .clear, lineWidth: 1)
                    )
                    .customRadius(.small)
            }

            // 메시지 버튼
            Button {
                viewStore.send(.messageButtonTapped)
            } label: {
                Text("메시지")
                    .font(.appBody)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.small.rawValue)
                            .stroke(AppColor.divider, lineWidth: 1)
                    )
                    .customRadius(.small)
            }
        }
    }

    // MARK: - 통계 섹션
    private func statsSection(viewStore: ViewStoreOf<OtherProfileFeature>) -> some View {
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
                        .foregroundColor(.secondary)
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
}

// MARK: - Preview
//#Preview {
//    NavigationStack {
//        OtherProfileView(
//            store: Store(
//                initialState: OtherProfileFeature.State(userId: "690e1970ff94927948fea0a3")
//            ) {
//                OtherProfileFeature()
//            }
//        )
//    }
//}
