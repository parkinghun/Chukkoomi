//
//  SharePostView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/18/25.
//

import SwiftUI
import ComposableArchitecture

struct SharePostView: View {
    let store: StoreOf<SharePostFeature>
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 검색 바 (터치 시 UserSearchView로 이동)
            Button {
                store.send(.searchBarTapped)
            } label: {
                HStack(spacing: AppPadding.small) {
                    AppIcon.search
                        .foregroundStyle(AppColor.textSecondary)

                    Text("검색")
                        .foregroundStyle(AppColor.textSecondary)
                        .font(.appBody)

                    Spacer()
                }
                .padding(.horizontal, AppPadding.medium)
                .padding(.vertical, AppPadding.small)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppColor.divider, lineWidth: 1)
                )
                .frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if store.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                userListSection
            }

            Spacer()

            sendButton
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            store.send(.onAppear)
        }
        .fullScreenCover(
            store: store.scope(state: \.$userSearch, action: \.userSearch)
        ) { store in
            NavigationStack {
                UserSearchView(store: store)
            }
        }
    }

    // MARK: - User List Section
    private var userListSection: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)

        ]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(store.availableUsers, id: \.userId) { user in
                    userCell(user: user)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - User Cell
    private func userCell(user: User) -> some View {
        let isSelected = store.selectedUserId == user.userId

        return VStack(spacing: 8) {
            ZStack {
                // 프로필 이미지
                if let profileImage = user.profileImage {
                    AsyncMediaImageView(
                        imagePath: profileImage,
                        width: 50,
                        height: 50
                    )
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay {
                            AppIcon.personFill
                                .foregroundStyle(.gray)
                                .font(.system(size: 24))
                        }
                }

                // 선택 표시
                if isSelected {
                    Circle()
                        .fill(AppColor.primary)
                        .frame(width: 20, height: 20)
                        .overlay(
                            AppIcon.checkmark
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 20, y: 20)
                }
            }
            .frame(width: 50, height: 50)

            Text(user.nickname)
                .font(.appCaption)
                .foregroundColor(.black)
                .lineLimit(1)
        }
        .buttonWrapper {
            store.send(.userTapped(user))
        }
    }

    // MARK: - Send Button
    private var sendButton: some View {
        FillButton(
            title: "전송",
            isLoading: false,
            isEnabled: store.canSend
        ) {
            store.send(.sendTapped)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

#Preview {
    SharePostView(
        store: Store(
            initialState: SharePostFeature.State(
                post: Post(
                    teams: .all,
                    title: "테스트",
                    price: 0,
                    content: "내용",
                    files: ["image1"]
                )
            )
        ) {
            SharePostFeature()
        }
    )
}
