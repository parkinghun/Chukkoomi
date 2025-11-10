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
                searchBar(viewStore: viewStore)
                    .padding(.horizontal, AppPadding.large)

                Divider()
                    .padding(.top, AppPadding.medium)

                // 검색 결과 리스트
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
                                    .onTapGesture {
                                        viewStore.send(.userTapped(result.user.userId))
                                    }

                                if result.id != viewStore.searchResults.last?.id {
                                    Divider()
                                        .padding(.leading, 80)
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
            .navigationTitle("유저 검색")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 검색바
    private func searchBar(viewStore: ViewStoreOf<UserSearchFeature>) -> some View {
        HStack(spacing: AppPadding.small) {
            AppIcon.search
                .foregroundColor(.secondary)

            TextField("닉네임으로 검색", text: viewStore.binding(
                get: \.searchText,
                send: { .searchTextChanged($0) }
            ))
            .focused($isSearchFieldFocused)
            .textFieldStyle(.plain)
            .submitLabel(.search)
            .onSubmit {
                viewStore.send(.search)
            }

            if !viewStore.searchText.isEmpty {
                Button {
                    viewStore.send(.clearSearch)
                } label: {
                    AppIcon.xmarkCircleFill
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, AppPadding.medium)
        .padding(.vertical, AppPadding.small)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AppColor.divider, lineWidth: 1)
        )
    }

    // MARK: - 유저 행
    private func userRow(result: UserSearchFeature.SearchResult, viewStore: ViewStoreOf<UserSearchFeature>) -> some View {
        HStack(spacing: AppPadding.medium) {
            // 프로필 이미지
            Group {
                if let imageData = result.profileImageData,
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
            Text(result.user.nickname)
                .font(.appBody)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, AppPadding.large)
        .padding(.vertical, AppPadding.medium)
        .background(Color.clear)
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
