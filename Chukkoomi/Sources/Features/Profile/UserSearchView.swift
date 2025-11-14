//
//  UserSearchView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/10/25.
//

import SwiftUI
import ComposableArchitecture

struct UserSearchView: View {
    let store: StoreOf<UserSearchFeature>
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
                        viewStore.send(.search)
                    },
                    onClear: {
                        viewStore.send(.clearSearch)
                    }
                )
                .padding(.horizontal, AppPadding.large)

                // 검색 결과 리스트
                searchResultsList(viewStore: viewStore)
                    .padding(.top, 4)
            }
            .navigationTitle("유저 검색")
            .navigationBarTitleDisplayMode(.inline)
            // 이 파일 전용 네비게이션 연결
            .modifier(UserSearchNavigation(store: store))
        }
    }

    // MARK: - 검색 결과 리스트
    private func searchResultsList(viewStore: ViewStoreOf<UserSearchFeature>) -> some View {
        Group {
            if viewStore.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewStore.isSearching && viewStore.searchResults.isEmpty {
                Spacer()
                Text("검색 결과가 없습니다")
                    .font(.appBody)
                    .foregroundColor(.secondary)
                Spacer()
            } else if !viewStore.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewStore.searchResults) { result in
                            userRow(result: result, viewStore: viewStore)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewStore.send(.userTapped(result.user.userId))
                                }
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        isSearchFieldFocused = false
                    }
                )
            } else {
                Spacer()
            }
        }
    }

    // MARK: - 유저 행
    private func userRow(result: UserSearchFeature.SearchResult, viewStore: ViewStoreOf<UserSearchFeature>) -> some View {
        HStack(spacing: AppPadding.medium) {
            // 프로필 이미지
            if let profileImagePath = result.user.profileImage {
                AsyncMediaImageView(
                    imagePath: profileImagePath,
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
                            .foregroundColor(.gray)
                            .font(.system(size: 24))
                    }
            }

            // 닉네임
            Text(result.user.nickname)
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
private struct UserSearchNavigation: ViewModifier {
    let store: StoreOf<UserSearchFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(
                store: store.scope(state: \.$otherProfile, action: \.otherProfile)
            ) { store in
                OtherProfileView(store: store)
            }
    }
}

// MARK: - Preview
//#Preview {
//    NavigationStack {
//        UserSearchView(
//            store: Store(
//                initialState: UserSearchFeature.State()
//            ) {
//                UserSearchFeature()
//            }
//        )
//    }
//}
