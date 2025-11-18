//
//  CommentFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/18/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct CommentFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        let postId: String
        let postCreatorName: String
        var comments: [Comment] = []
        var commentText: String = ""
        var isLoading: Bool = false
        var isSending: Bool = false

        // 수정/삭제 메뉴
        var editingCommentId: String?
        var editingComment: Comment? // 수정 중인 댓글
        @Presents var menu: ConfirmationDialogState<Action.Menu>?
        @Presents var deleteAlert: AlertState<Action.DeleteAlert>?

        // 프로필 네비게이션
        @Presents var myProfile: MyProfileFeature.State?
        @Presents var otherProfile: OtherProfileFeature.State?

        // 수정 모드 여부
        var isEditMode: Bool {
            editingComment != nil
        }

        // 원본 댓글과 동일한지 확인
        var isCommentUnchanged: Bool {
            guard let originalContent = editingComment?.content else { return false }
            return commentText.trimmingCharacters(in: .whitespacesAndNewlines) == originalContent
        }

        var canSendComment: Bool {
            let trimmedText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedText.isEmpty && !isSending && !isCommentUnchanged
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case loadComments
        case commentsLoaded(Result<[Comment], Error>)
        case commentTextChanged(String)
        case sendComment
        case commentSent(Result<Comment, Error>)
        case updateComment
        case commentUpdated(Result<Comment, Error>)
        case cancelEdit
        case profileTapped(String) // userId
        case commentMenuTapped(String) // commentId
        case menu(PresentationAction<Menu>)
        case deleteAlert(PresentationAction<DeleteAlert>)
        case deleteComment
        case deleteCommentResponse(Result<Void, Error>)
        case myProfile(PresentationAction<MyProfileFeature.Action>)
        case otherProfile(PresentationAction<OtherProfileFeature.Action>)
        case delegate(Delegate)

        enum Menu: Equatable {
            case edit
            case delete
        }

        enum DeleteAlert: Equatable {
            case confirmDelete
        }

        enum Delegate: Equatable {
            case commentCountChanged(Int) // delta: +1 for create, -1 for delete
            case myProfileTapped
            case otherProfileTapped(String) // userId
        }

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.loadComments, .loadComments),
                 (.sendComment, .sendComment),
                 (.updateComment, .updateComment),
                 (.cancelEdit, .cancelEdit),
                 (.deleteComment, .deleteComment):
                return true
            case let (.commentTextChanged(lhs), .commentTextChanged(rhs)):
                return lhs == rhs
            case let (.profileTapped(lhs), .profileTapped(rhs)):
                return lhs == rhs
            case let (.commentMenuTapped(lhs), .commentMenuTapped(rhs)):
                return lhs == rhs
            case let (.commentsLoaded(lhsResult), .commentsLoaded(rhsResult)):
                switch (lhsResult, rhsResult) {
                case (.success(let lhs), .success(let rhs)):
                    return lhs.count == rhs.count
                case (.failure, .failure):
                    return true
                default:
                    return false
                }
            case (.commentSent, .commentSent),
                 (.commentUpdated, .commentUpdated),
                 (.deleteCommentResponse, .deleteCommentResponse):
                return true
            case let (.menu(lhs), .menu(rhs)):
                return lhs == rhs
            case let (.deleteAlert(lhs), .deleteAlert(rhs)):
                return lhs == rhs
            case let (.myProfile(lhs), .myProfile(rhs)):
                return lhs == rhs
            case let (.otherProfile(lhs), .otherProfile(rhs)):
                return lhs == rhs
            case let (.delegate(lhs), .delegate(rhs)):
                return lhs == rhs
            default:
                return false
            }
        }
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .send(.loadComments)

            case .loadComments:
                return .run { [postId = state.postId] send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            CommentRouter.fetchComments(postId: postId),
                            as: CommentListDTO.self
                        )
                        let comments = response.data.map { $0.toDomain }
                        await send(.commentsLoaded(.success(comments)))
                    } catch {
                        print("❌ 댓글 로드 실패: \(error)")
                        await send(.commentsLoaded(.failure(error)))
                    }
                }

            case let .commentsLoaded(.success(comments)):
                state.isLoading = false
                state.comments = comments
                print("✅ 댓글 로드 완료: \(comments.count)개")
                return .none

            case .commentsLoaded(.failure):
                state.isLoading = false
                return .none

            case let .commentTextChanged(text):
                state.commentText = text
                return .none

            case let .profileTapped(userId):
                let myUserId = UserDefaultsHelper.userId

                if userId == myUserId {
                    state.myProfile = MyProfileFeature.State(isPresented: true)
                    return .none
                } else {
                    state.otherProfile = OtherProfileFeature.State(userId: userId, isPresented: true)
                    return .none
                }

            case .sendComment:
                // 수정 모드일 경우 updateComment로 분기
                if state.isEditMode {
                    return .send(.updateComment)
                }

                guard !state.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return .none
                }

                state.isSending = true
                let content = state.commentText

                return .run { [postId = state.postId] send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            CommentRouter.createComment(postId: postId, content: content),
                            as: CommentResponseDTO.self
                        )
                        let comment = response.toDomain
                        await send(.commentSent(.success(comment)))
                    } catch {
                        print("❌ 댓글 작성 실패: \(error)")
                        await send(.commentSent(.failure(error)))
                    }
                }

            case let .commentSent(.success(comment)):
                state.isSending = false
                state.commentText = ""
                state.comments.insert(comment, at: 0) // 최신 댓글이 위로
                print("✅ 댓글 작성 완료")
                return .send(.delegate(.commentCountChanged(1))) // 댓글 수 +1

            case .commentSent(.failure):
                state.isSending = false
                // TODO: 에러 토스트 표시
                return .none

            case .updateComment:
                guard let editingComment = state.editingComment,
                      !state.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !state.isCommentUnchanged else {
                    return .none
                }

                state.isSending = true
                let content = state.commentText

                return .run { [postId = state.postId, commentId = editingComment.id] send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            CommentRouter.updateComment(postId: postId, commentId: commentId, content: content),
                            as: CommentResponseDTO.self
                        )
                        let comment = response.toDomain
                        await send(.commentUpdated(.success(comment)))
                    } catch {
                        print("❌ 댓글 수정 실패: \(error)")
                        await send(.commentUpdated(.failure(error)))
                    }
                }

            case let .commentUpdated(.success(comment)):
                state.isSending = false
                state.commentText = ""
                state.editingComment = nil
                state.editingCommentId = nil

                // 댓글 목록에서 해당 댓글 업데이트
                if let index = state.comments.firstIndex(where: { $0.id == comment.id }) {
                    state.comments[index] = comment
                }
                print("✅ 댓글 수정 완료")
                return .none

            case .commentUpdated(.failure):
                state.isSending = false
                // TODO: 에러 토스트 표시
                return .none

            case .cancelEdit:
                state.editingComment = nil
                state.editingCommentId = nil
                state.commentText = ""
                return .none

            case let .commentMenuTapped(commentId):
                state.editingCommentId = commentId
                state.menu = ConfirmationDialogState {
                    TextState("댓글 관리")
                } actions: {
                    ButtonState(action: .edit) {
                        TextState("수정하기")
                    }
                    ButtonState(role: .destructive, action: .delete) {
                        TextState("삭제하기")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                }
                return .none

            case .menu(.presented(.edit)):
                // 수정 모드 진입
                guard let commentId = state.editingCommentId,
                      let comment = state.comments.first(where: { $0.id == commentId }) else {
                    return .none
                }
                state.editingComment = comment
                state.commentText = comment.content
                return .none

            case .menu(.presented(.delete)):
                // 삭제 확인 Alert 표시
                state.deleteAlert = AlertState {
                    TextState("댓글을 삭제하시겠어요?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("삭제하기")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("삭제한 댓글은 복구할 수 없습니다.")
                }
                return .none

            case .menu:
                return .none

            case .deleteAlert(.presented(.confirmDelete)):
                guard let commentId = state.editingCommentId else { return .none }
                return .send(.deleteComment)

            case .deleteAlert:
                return .none

            case .deleteComment:
                guard let commentId = state.editingCommentId else { return .none }

                return .run { [postId = state.postId] send in
                    do {
                        try await NetworkManager.shared.performRequestWithoutResponse(CommentRouter.deleteComment(postId: postId, commentId: commentId))
                        await send(.deleteCommentResponse(.success(())))
                    } catch {
                        print("❌ 댓글 삭제 실패: \(error)")
                        await send(.deleteCommentResponse(.failure(error)))
                    }
                }

            case .deleteCommentResponse(.success):
                // 댓글 목록에서 제거
                if let commentId = state.editingCommentId {
                    state.comments.removeAll { $0.id == commentId }
                    print("✅ 댓글 삭제 완료")
                }
                state.editingCommentId = nil
                return .send(.delegate(.commentCountChanged(-1))) // 댓글 수 -1

            case .deleteCommentResponse(.failure):
                state.editingCommentId = nil
                // TODO: 에러 토스트 표시
                return .none

            case .myProfile:
                return .none

            case .otherProfile:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$menu, action: \.menu)
        .ifLet(\.$deleteAlert, action: \.deleteAlert)
        .ifLet(\.$myProfile, action: \.myProfile) {
            MyProfileFeature()
        }
        .ifLet(\.$otherProfile, action: \.otherProfile) {
            OtherProfileFeature()
        }
    }
}
