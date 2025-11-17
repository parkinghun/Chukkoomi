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
            // 검색 바
            SearchBar(
                text: Binding(
                    get: { store.searchText },
                    set: { store.send(.searchTextChanged($0)) }
                ),
                isFocused: $isSearchFocused,
                placeholder: "검색",
                onSubmit: {
                    store.send(.searchSubmitted)
                },
                onClear: {
                    store.send(.searchCleared)
                }
            )
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
                ForEach(store.filteredUsers, id: \.userId) { user in
                    userCell(user: user)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - User Cell
    private func userCell(user: User) -> some View {
        let isSelected = store.selectedUsers.contains(user.userId)

        return VStack(spacing: 8) {
            ZStack {
                // 프로필 이미지
                if let profileImage = user.profileImage {
                    AsyncMediaImageView(
                        imagePath: profileImage,
                        width: 70,
                        height: 70
                    )
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
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
                        .offset(x: 25, y: 25)
                }
            }
            .frame(width: 70, height: 70)

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
