//
//  PostRouter.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import Foundation

// MARK: - Query Parameters
extension PostRouter {
    /// 기본 페이지네이션 쿼리 (next, limit, category)
    struct ListQuery {
        var next: String?
        var limit: Int?
        var category: [String]?
    }

    /// 해시태그 검색 쿼리
    struct HashtagQuery {
        let hashtag: String
        var next: String?
        var limit: Int?
    }

    /// 위치 기반 검색 쿼리
    struct LocationQuery {
        var category: [String]?
        var longitude: Double?
        var latitude: Double?
        var maxDistance: Int?
        var orderBy: String?  // "distance" or "createdAt"
        var sortBy: String?   // "asc" or "desc"
    }

    /// 제목 검색 쿼리
    struct TitleQuery {
        let title: String
        var category: [String]?
    }
}

// MARK: - Router Cases
enum PostRouter {
    // POST
    case uploadFiles([MultipartFile])
    case createPost(PostRequestDTO)
    case likePost(postId: String, likeStatus: Bool)
    case bookmarkPost(postId: String, likeStatus: Bool)

    // GET
    case fetchPosts(ListQuery)
    case fetchPost(String)
    case fetchLikedPosts(next: String?, limit: Int?)
    case fetchBookmarkedPosts(next: String?, limit: Int?)
    case fetchUserPosts(userId: String, ListQuery)
    case fetchFollowerPosts(ListQuery)
    case fetchPostsByHashtag(HashtagQuery)
    case fetchPostsByLocation(LocationQuery)
    case fetchPostsByTitle(TitleQuery)

    // PUT
    case updatePost(postId: String, PostRequestDTO)

    // DELETE
    case deletePost(String)
}

extension PostRouter: Router {

    var version: String {
        return "v1"
    }

    var path: String {
        let base = "/\(version)/posts"

        switch self {
        case .uploadFiles:
            return "\(base)/files"
        case .createPost, .fetchPosts:
            return base
        case .likePost(let postId, _):
            return "\(base)/\(postId)/like"
        case .bookmarkPost(let postId, _):
            return "\(base)/\(postId)/like-2"
        case .fetchPost(let postId), .updatePost(let postId, _), .deletePost(let postId):
            return "\(base)/\(postId)"
        case .fetchLikedPosts:
            return "\(base)/likes/me"
        case .fetchBookmarkedPosts:
            return "\(base)/likes-2/me"
        case .fetchUserPosts(let userId, _):
            return "\(base)/users/\(userId)"
        case .fetchPostsByHashtag:
            return "\(base)/hashtags"
        case .fetchFollowerPosts:
            return "\(base)/feed"
        case .fetchPostsByLocation:
            return "\(base)/geolocation"
        case .fetchPostsByTitle:
            return "\(base)/search"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .uploadFiles, .createPost, .likePost, .bookmarkPost:
            return .post
        case .fetchPosts, .fetchPost, .fetchLikedPosts, .fetchBookmarkedPosts, .fetchUserPosts, .fetchPostsByHashtag, .fetchFollowerPosts, .fetchPostsByLocation, .fetchPostsByTitle:
            return .get
        case .updatePost:
            return .put
        case .deletePost:
            return .delete
        }
    }

    var headers: [HTTPHeader]? {
        return HTTPHeader.basic
    }

    var body: AnyEncodable? {
        switch self {
        case .uploadFiles(let files):
            return .init(UploadFilesRequestBody(files: files))
        case .createPost(let post), .updatePost(_, let post):
            return .init(post)
        case .likePost(_, let status), .bookmarkPost(_, let status):
            return .init(LikeRequestBody(likeStatus: status))
        default:
            return nil
        }
    }

    var bodyEncoder: BodyEncoder? {
        switch self {
        case .uploadFiles:
            return .multipart
        case .createPost, .updatePost, .likePost, .bookmarkPost:
            return .json
        default:
            return nil
        }
    }

    var query: [HTTPQuery]? {
        switch self {
        case .fetchPosts(let listQuery),
             .fetchUserPosts(_, let listQuery),
             .fetchFollowerPosts(let listQuery):
            return QueryBuilder()
                .add(next: listQuery.next)
                .add(limit: listQuery.limit)
                .add(category: listQuery.category)
                .build()

        case .fetchLikedPosts(let next, let limit),
             .fetchBookmarkedPosts(let next, let limit):
            return QueryBuilder()
                .add(next: next)
                .add(limit: limit)
                .build()

        case .fetchPostsByHashtag(let query):
            return QueryBuilder()
                .add(key: "hashTag", value: query.hashtag)
                .add(next: query.next)
                .add(limit: query.limit)
                .build()

        case .fetchPostsByLocation(let query):
            return QueryBuilder()
                .add(category: query.category)
                .add(key: "longitude", value: query.longitude)
                .add(key: "latitude", value: query.latitude)
                .add(key: "maxDistance", value: query.maxDistance)
                .add(key: "orderBy", value: query.orderBy)
                .add(key: "sortBy", value: query.sortBy)
                .build()

        case .fetchPostsByTitle(let query):
            return QueryBuilder()
                .add(key: "title", value: query.title)
                .add(category: query.category)
                .build()

        case .uploadFiles, .createPost, .fetchPost, .updatePost, .deletePost, .likePost, .bookmarkPost:
            return nil
        }
    }
}

// MARK: - Query Builder
private struct QueryBuilder {
    private var queries: [HTTPQuery] = []

    @discardableResult
    func add(next: String?) -> Self {
        guard let next = next, !next.isEmpty else { return self }
        var builder = self
        builder.queries.append(.next(next))
        return builder
    }

    @discardableResult
    func add(limit: Int?) -> Self {
        guard let limit = limit else { return self }
        var builder = self
        builder.queries.append(.limit(limit))
        return builder
    }

    @discardableResult
    func add(category: [String]?) -> Self {
        guard let category = category, !category.isEmpty else { return self }
        var builder = self
        builder.queries.append(.category(category))
        return builder
    }

    @discardableResult
    func add(key: String, value: String?) -> Self {
        guard let value = value, !value.isEmpty else { return self }
        var builder = self
        builder.queries.append(.custom(key: key, value: value))
        return builder
    }

    @discardableResult
    func add(key: String, value: Double?) -> Self {
        guard let value = value else { return self }
        var builder = self
        builder.queries.append(.custom(key: key, value: "\(value)"))
        return builder
    }

    @discardableResult
    func add(key: String, value: Int?) -> Self {
        guard let value = value else { return self }
        var builder = self
        builder.queries.append(.custom(key: key, value: "\(value)"))
        return builder
    }

    func build() -> [HTTPQuery]? {
        queries.isEmpty ? nil : queries
    }
}

// MARK: - Body 객체
extension PostRouter {

    /// 파일 업로드 요청 바디
    struct UploadFilesRequestBody: Encodable {
        let files: [MultipartFile]

        func encode(to encoder: Encoder) throws {
            // MultipartFormDataEncoder는 Mirror를 사용하므로 이 메서드는 호출되지 않음
            // AnyEncodable의 제네릭 제약(<T: Encodable>)을 만족시키기 위해서만 필요
        }
    }

    /// 좋아요/북마크 요청 바디
    struct LikeRequestBody: Encodable {
        let likeStatus: Bool

        enum CodingKeys: String, CodingKey {
            case likeStatus = "like_status"
        }
    }
}
