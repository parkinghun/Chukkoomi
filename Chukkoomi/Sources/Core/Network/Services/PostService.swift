//
//  PostService.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import Foundation

/// Post 관련 네트워크 작업을 담당하는 서비스 프로토콜
protocol PostServiceProtocol {
    /// 게시글 목록 조회
    func fetchPosts(query: PostRouter.ListQuery) async throws -> PostListResponseDTO

    /// 게시글 상세 조회
    func fetchPost(postId: String) async throws -> PostResponseDTO

    /// 게시글 작성 (Data 배열 - 자동 타입 감지)
    func createPost(post: PostRequestDTO, images: [Data]) async throws -> PostResponseDTO

    /// 게시글 작성 (FileData 배열 - 명시적 타입 지정)
    func createPost(post: PostRequestDTO, files: [FileData]) async throws -> PostResponseDTO

    /// 게시글 수정 (Data 배열 - 자동 타입 감지)
    func updatePost(postId: String, post: PostRequestDTO, images: [Data]) async throws -> PostResponseDTO

    /// 게시글 수정 (FileData 배열 - 명시적 타입 지정)
    func updatePost(postId: String, post: PostRequestDTO, files: [FileData]) async throws -> PostResponseDTO

    /// 게시글 삭제
    func deletePost(postId: String) async throws -> Void

    /// 좋아요 토글
    func toggleLike(postId: String, likeStatus: Bool) async throws -> PostLikeResponseDTO

    /// 북마크 토글 (좋아요2)
    func toggleBookmark(postId: String, likeStatus: Bool) async throws -> PostLikeResponseDTO

    /// 해시태그로 게시글 검색
    func searchByHashtag(query: PostRouter.HashtagQuery) async throws -> PostListResponseDTO

    /// 위치 기반 게시글 조회
    func fetchPostsByLocation(query: PostRouter.LocationQuery) async throws -> PostListResponseDTO

    /// 제목으로 게시글 검색
    func searchByTitle(query: PostRouter.TitleQuery) async throws -> PostListResponseDTO

    /// 내가 좋아요한 게시글 조회
    func fetchLikedPosts(next: String?, limit: Int?) async throws -> PostListResponseDTO
}

/// PostService 실제 구현
final class PostService: PostServiceProtocol {

    static let shared = PostService()

    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    // MARK: - 게시글 목록 조회

    func fetchPosts(query: PostRouter.ListQuery) async throws -> PostListResponseDTO {
        return try await networkManager.performRequest(
            PostRouter.fetchPosts(query),
            as: PostListResponseDTO.self
        )
    }

    // MARK: - 게시글 상세 조회

    func fetchPost(postId: String) async throws -> PostResponseDTO {
        return try await networkManager.performRequest(
            PostRouter.fetchPost(postId),
            as: PostResponseDTO.self
        )
    }

    // MARK: - 게시글 작성

    /// Data 배열로 게시글 작성 (자동 타입 감지)
    func createPost(post: PostRequestDTO, images: [Data] = []) async throws -> PostResponseDTO {
        var finalPost = post

        // 이미지가 있으면 먼저 업로드
        if !images.isEmpty {
            let uploadedFileURLs = try await uploadFiles(images)

            // 기존 files에 업로드된 URL 추가
            var allFiles = post.files
            allFiles.append(contentsOf: uploadedFileURLs)
            finalPost.files = allFiles
        }

        return try await networkManager.performRequest(
            PostRouter.createPost(finalPost),
            as: PostResponseDTO.self
        )
    }

    /// FileData 배열로 게시글 작성 (명시적 타입 지정)
    func createPost(post: PostRequestDTO, files: [FileData]) async throws -> PostResponseDTO {
        var finalPost = post

        // 파일이 있으면 먼저 업로드
        if !files.isEmpty {
            let uploadedFileURLs = try await uploadFiles(files)

            // 기존 files에 업로드된 URL 추가
            var allFiles = post.files
            allFiles.append(contentsOf: uploadedFileURLs)
            finalPost.files = allFiles
        }

        return try await networkManager.performRequest(
            PostRouter.createPost(finalPost),
            as: PostResponseDTO.self
        )
    }

    // MARK: - 게시글 수정

    /// Data 배열로 게시글 수정 (자동 타입 감지)
    func updatePost(postId: String, post: PostRequestDTO, images: [Data] = []) async throws -> PostResponseDTO {
        var finalPost = post

        // 이미지가 있으면 먼저 업로드
        if !images.isEmpty {
            let uploadedFileURLs = try await uploadFiles(images)

            // 기존 files에 업로드된 URL 추가
            var allFiles = post.files
            allFiles.append(contentsOf: uploadedFileURLs)
            finalPost.files = allFiles
        }

        return try await networkManager.performRequest(
            PostRouter.updatePost(postId: postId, finalPost),
            as: PostResponseDTO.self
        )
    }

    /// FileData 배열로 게시글 수정 (명시적 타입 지정)
    func updatePost(postId: String, post: PostRequestDTO, files: [FileData]) async throws -> PostResponseDTO {
        var finalPost = post

        // 파일이 있으면 먼저 업로드
        if !files.isEmpty {
            let uploadedFileURLs = try await uploadFiles(files)

            // 기존 files에 업로드된 URL 추가
            var allFiles = post.files
            allFiles.append(contentsOf: uploadedFileURLs)
            finalPost.files = allFiles
        }

        return try await networkManager.performRequest(
            PostRouter.updatePost(postId: postId, finalPost),
            as: PostResponseDTO.self
        )
    }

    // MARK: - 게시글 삭제

    func deletePost(postId: String) async throws {
        let _: EmptyResponse = try await networkManager.performRequest(
            PostRouter.deletePost(postId),
            as: EmptyResponse.self
        )
    }

    // MARK: - 좋아요 토글

    func toggleLike(postId: String, likeStatus: Bool) async throws -> PostLikeResponseDTO {
        return try await networkManager.performRequest(
            PostRouter.likePost(postId: postId, likeStatus: likeStatus),
            as: PostLikeResponseDTO.self
        )
    }

    // MARK: - 북마크 토글

    func toggleBookmark(postId: String, likeStatus: Bool) async throws -> PostLikeResponseDTO {
        return try await networkManager.performRequest(
            PostRouter.bookmarkPost(postId: postId, likeStatus: likeStatus),
            as: PostLikeResponseDTO.self
        )
    }

    // MARK: - 해시태그 검색

    func searchByHashtag(query: PostRouter.HashtagQuery) async throws -> PostListResponseDTO {
        return try await networkManager.performRequest(
            PostRouter.fetchPostsByHashtag(query),
            as: PostListResponseDTO.self
        )
    }

    // MARK: - 위치 기반 조회

    func fetchPostsByLocation(query: PostRouter.LocationQuery) async throws -> PostListResponseDTO {
        return try await networkManager.performRequest(
            PostRouter.fetchPostsByLocation(query),
            as: PostListResponseDTO.self
        )
    }

    // MARK: - 제목 검색

    func searchByTitle(query: PostRouter.TitleQuery) async throws -> PostListResponseDTO {
        return try await networkManager.performRequest(
            PostRouter.fetchPostsByTitle(query),
            as: PostListResponseDTO.self
        )
    }

    // MARK: - 좋아요한 게시글 조회

    func fetchLikedPosts(next: String?, limit: Int?) async throws -> PostListResponseDTO {
        return try await networkManager.performRequest(
            PostRouter.fetchLikedPosts(next: next, limit: limit),
            as: PostListResponseDTO.self
        )
    }

    // MARK: - Private Helper Methods

    /// 파일 업로드 (내부 전용)
    /// - Parameter files: 업로드할 파일 데이터 배열 (이미지, 동영상, 기타 파일)
    /// - Returns: 업로드된 파일 URL 배열
    /// - Note: 최대 5개, 각 파일 최대 10MB
    private func uploadFiles(_ files: [FileData]) async throws -> [String] {
        // 파일 개수 검증 (최대 5개)
        guard files.count <= 5 else {
            throw FileUploadError.tooManyFiles(count: files.count, maxCount: 5)
        }

        // 파일 크기 검증 (각 파일 최대 10MB)
        let maxFileSize = 10 * 1024 * 1024  // 10MB in bytes
        for file in files {
            guard !file.data.isEmpty else {
                throw FileUploadError.emptyFile
            }

            guard file.data.count <= maxFileSize else {
                throw FileUploadError.fileTooLarge(
                    size: file.data.count,
                    maxSize: maxFileSize
                )
            }
        }

        // FileData를 MultipartFile로 변환
        let multipartFiles = files.map { fileData in
            MultipartFile(
                data: fileData.data,
                fileName: fileData.fileName,
                mimeType: fileData.mimeType
            )
        }

        // 파일 업로드 요청
        let response = try await networkManager.performRequest(
            PostRouter.uploadFiles(multipartFiles),
            as: FileUploadDTO.self
        )

        print("📤 파일 \(files.count)개 업로드 완료")
        files.forEach { file in
            let sizeMB = Double(file.data.count) / 1024.0 / 1024.0
            print("   - \(file.fileName) (\(String(format: "%.2f", sizeMB))MB, \(file.mimeType))")
        }

        return response.files
    }

    /// Data 배열을 FileData로 자동 변환하여 업로드 (편의 메서드)
    private func uploadFiles(_ dataArray: [Data]) async throws -> [String] {
        let files = dataArray.map { FileData(data: $0) }
        return try await uploadFiles(files)
    }
}

// MARK: - Helper DTOs

/// 빈 응답용 DTO
private struct EmptyResponse: Decodable {}
