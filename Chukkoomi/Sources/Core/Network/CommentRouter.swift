//
//  CommentRouter.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/18/25.
//

import Foundation

enum CommentRouter {
    case fetchComments(postId: String)
    case createComment(postId: String, content: String)
    case createReply(postId: String, commentId: String, content: String)  // 대댓글
    case updateComment(postId: String, commentId: String, content: String)
    case deleteComment(postId: String, commentId: String)
}

extension CommentRouter: Router {

    var version: String { "v1" }

    var path: String {
        let base = "/\(version)/posts"

        switch self {
        case let .fetchComments(postId):
            return "\(base)/\(postId)/comments"

        case let .createComment(postId, _):
            return "\(base)/\(postId)/comments"

        case let .createReply(postId, commentId, _):
            return "\(base)/\(postId)/comments/\(commentId)/replies"

        case let .updateComment(postId, commentId, _):
            return "\(base)/\(postId)/comments/\(commentId)"

        case let .deleteComment(postId, commentId):
            return "\(base)/\(postId)/comments/\(commentId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fetchComments:
            return .get

        case .createComment, .createReply:
            return .post

        case .updateComment:
            return .put

        case .deleteComment:
            return .delete
        }
    }

    var headers: [HTTPHeader]? {
        HTTPHeader.basic
    }

    var body: AnyEncodable? {
        switch self {
        case .createComment(_, let content),
             .createReply(_, _, let content),
             .updateComment(_, _, let content):
            return .init(CommentRequestBody(content: content))

        case .fetchComments,
             .deleteComment:
            return nil
        }
    }

    var bodyEncoder: BodyEncoder? {
        switch self {
        case .createComment,
             .createReply,
             .updateComment:
            return .json

        case .fetchComments,
             .deleteComment:
            return nil
        }
    }

    var query: [HTTPQuery]? {
        return nil  // 댓글 API에는 쿼리 파라미터 없음
    }
}

// MARK: - Request DTO
extension CommentRouter {
    struct CommentRequestBody: Encodable {
        let content: String
    }
}
