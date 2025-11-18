//
//  CommentView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/18/25.
//

import SwiftUI
import ComposableArchitecture

struct CommentView: View {
    let store: StoreOf<CommentFeature>
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerView

            Divider()

            // 댓글 리스트
            if store.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if store.comments.isEmpty {
                emptyStateView
            } else {
                commentListView
            }

            Divider()

            // 댓글 입력 필드
            commentInputView
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            store.send(.onAppear)
        }
        .confirmationDialog(
            store: store.scope(state: \.$menu, action: \.menu)
        )
        .alert(
            store: store.scope(state: \.$deleteAlert, action: \.deleteAlert)
        )
        .fullScreenCover(
            store: store.scope(state: \.$myProfile, action: \.myProfile)
        ) { store in
            NavigationStack {
                MyProfileView(store: store)
            }
        }
        .fullScreenCover(
            store: store.scope(state: \.$otherProfile, action: \.otherProfile)
        ) { store in
            NavigationStack {
                OtherProfileView(store: store)
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Spacer()
            Text("댓글")
                .font(.headline)
                .foregroundColor(.black)
            Spacer()
        }
        .padding(.vertical, 16)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("작성된 댓글이 없어요")
                .font(.appBody)
                .foregroundColor(AppColor.textSecondary)
            Spacer()
        }
    }

    // MARK: - Comment List
    private var commentListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(store.comments) { comment in
                    commentCell(comment: comment)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Comment Cell
    private func commentCell(comment: Comment) -> some View {
        let isMyComment = comment.creator.userId == UserDefaultsHelper.userId

        return HStack(alignment: .top, spacing: 12) {
            // 프로필 영역 (이미지 + 이름/시간/내용)
            HStack(alignment: .top, spacing: 12) {
                // 프로필 이미지
                if let profileImagePath = comment.creator.profileImage {
                    AsyncMediaImageView(
                        imagePath: profileImagePath,
                        width: 40,
                        height: 40
                    )
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    // 이름 + 날짜
                    HStack(spacing: 8) {
                        Text(comment.creator.nickname)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)

                        Text(timeAgoString(from: comment.createdAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // 댓글 내용
                    Text(comment.content)
                        .font(.appBody)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .buttonWrapper {
                store.send(.profileTapped(comment.creator.userId))
            }

            Spacer()

            // 내 댓글이면 메뉴 버튼
            if isMyComment {
                Button {
                    store.send(.commentMenuTapped(comment.id))
                } label: {
                    AppIcon.ellipsis
                        .font(.system(size: 16))
                        .foregroundStyle(.gray)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Comment Input
    private var commentInputView: some View {
        VStack(spacing: 8) {
            // 수정 모드 헤더
            if store.isEditMode {
                HStack {
                    Text("댓글 수정 중")
                        .font(.caption)
                        .foregroundColor(AppColor.textSecondary)

                    Spacer()

                    Button {
                        store.send(.cancelEdit)
                    } label: {
                        Text("취소")
                            .font(.caption)
                            .foregroundColor(AppColor.primary)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                // 텍스트 필드
                HStack(spacing: 8) {
                    TextField(
                        store.isEditMode ? "댓글 수정" : "\(store.postCreatorName)님에게 댓글 추가",
                        text: Binding(
                            get: { store.commentText },
                            set: { store.send(.commentTextChanged($0)) }
                        )
                    )
                    .focused($isTextFieldFocused)
                    .font(.appBody)
                    .submitLabel(.send)
                    .onSubmit {
                        if store.canSendComment {
                            store.send(.sendComment)
                        }
                    }

                    if store.isSending {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else if store.canSendComment {
                        Button {
                            store.send(.sendComment)
                        } label: {
                            Image(systemName: store.isEditMode ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppColor.primary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Time Ago String
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let day = components.day, day > 0 {
            return "\(day)일전"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)시간전"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)분전"
        } else {
            return "방금"
        }
    }
}

#Preview {
    CommentView(
        store: Store(
            initialState: CommentFeature.State(
                postId: "test",
                postCreatorName: "테스트 작성자"
            )
        ) {
            CommentFeature()
        }
    )
}
