//
//  FollowListView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/11/25.
//

import SwiftUI
import ComposableArchitecture

struct FollowListView: View {
    let store: StoreOf<FollowListFeature>
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 검색바
                SearchBar(
                    text: viewStore.binding(
                        get: \.searchText,
                        send: { .searchTextChanged($0) }
                    ),
                    isFocused: $isSearchFieldFocused,
                    placeholder: "닉네임으로 검색",
                    onSubmit: {
                        // 검색은 실시간으로 이루어지므로 onSubmit은 빈 동작
                    },
                    onClear: {
                        viewStore.send(.clearSearch)
                    }
                )
                .padding(.horizontal, AppPadding.large)

                // 리스트
                userList(viewStore: viewStore)
                    .padding(.top, 4)
            }
            .navigationTitle(viewStore.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewStore.send(.onAppear)
            }
            // 네비게이션 연결
            .modifier(FollowListNavigation(store: store))
        }
    }

    // MARK: - 유저 리스트
    private func userList(viewStore: ViewStoreOf<FollowListFeature>) -> some View {
        Group {
            if viewStore.filteredUsers.isEmpty {
                Spacer()
                Text(viewStore.searchText.isEmpty ? "목록이 비어있습니다" : "검색 결과가 없습니다")
                    .font(.appBody)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewStore.filteredUsers) { userItem in
                            userRow(userItem: userItem, viewStore: viewStore)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewStore.send(.userTapped(userItem.user.userId))
                                }
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        isSearchFieldFocused = false
                    }
                )
            }
        }
    }

    // MARK: - 유저 행
    private func userRow(userItem: FollowListFeature.UserItem, viewStore: ViewStoreOf<FollowListFeature>) -> some View {
        HStack(spacing: AppPadding.medium) {
            // 프로필 이미지
            Group {
                if let imageData = userItem.profileImageData,
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
                                .font(.system(size: 24))
                        }
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            // 닉네임
            Text(userItem.user.nickname)
                .font(.appBody)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, AppPadding.large)
        .padding(.vertical, 4)
        .background(Color.clear)
    }
}

// MARK: - Navigation 구성
private struct FollowListNavigation: ViewModifier {
    let store: StoreOf<FollowListFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(
                store: store.scope(state: \.$otherProfile, action: \.otherProfile)
            ) { store in
                OtherProfileView(store: store)
            }
    }
}
