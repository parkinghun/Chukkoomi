//
//  PurchaseManager.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/26/25.
//

import Foundation

/// 구매 관련 에러
enum PurchaseError: Error, LocalizedError {
    case userNotLoggedIn
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .userNotLoggedIn:
            return "로그인이 필요합니다"
        case .syncFailed:
            return "구매 이력 동기화 실패"
        }
    }
}

/// 필터 구매 이력 관리
actor PurchaseManager {
    static let shared = PurchaseManager()

    // MARK: - Properties

    /// 구매한 필터 postId 목록 (캐시)
    private var purchasedFilterPostIds: Set<String> = []

    /// 사용 가능한 유료 필터 목록
    private var availableFilters: [PaidFilter] = []

    /// UserDefaults 키
    private let purchasedFiltersKey = "com.chukkoomi.purchasedFilters"

    // MARK: - Initialization

    private init() {
        // 로컬 캐시 로드
        loadFromUserDefaults()
    }

    // MARK: - Public Methods

    /// 필터 구매 여부 확인
    /// - Parameter filter: 확인할 ImageFilter
    /// - Returns: 구매 여부
    func isPurchased(_ filter: ImageFilter) -> Bool {
        guard filter.isPaid else { return true }

        // 해당 필터의 postId 찾기
        guard let paidFilter = availableFilters.first(where: { $0.imageFilter == filter }) else {
            return false
        }

        return purchasedFilterPostIds.contains(paidFilter.id)
    }

    /// 서버에서 구매 이력 동기화 (개선된 버전)
    /// - Throws: 네트워크 오류
    ///
    /// # 개선 사항
    /// - 하나의 API 호출로 유료 필터 목록 + 구매 여부 확인
    /// - Payment 카테고리 게시글의 `buyers` 배열 활용
    /// - `/payments/me` API 제거로 네트워크 요청 절약
    func syncPurchaseHistory() async throws {
        // 현재 사용자 ID 가져오기
        guard let currentUserId = UserDefaultsHelper.userId else {
            throw PurchaseError.userNotLoggedIn
        }

        // Payment 카테고리 게시글 조회 (유료 필터 목록)
        let filterPostsResponse = try await PostService.shared.fetchPosts(
            query: PostRouter.ListQuery(
                next: nil,
                limit: nil,
                category: [FootballTeams.payment.identifier]
            )
        )

        // Post를 PaidFilter로 변환
        let posts = filterPostsResponse.data.map { $0.toDomain }
        let filters = posts.compactMap { PaidFilter.from(post: $0) }

        availableFilters = filters

        // buyers 배열에서 구매 여부 확인
        var purchasedPostIds = Set<String>()

        for post in posts {
            if let buyers = post.buyers, buyers.contains(currentUserId) {
                purchasedPostIds.insert(post.id)

                if let filter = filters.first(where: { $0.id == post.id }) {
                    print("구매함: \(filter.title) (\(filter.price)원)")
                }
            } else {
                if let filter = filters.first(where: { $0.id == post.id }) {
                    print("미구매: \(filter.title) (\(filter.price)원)")
                }
            }
        }

        purchasedFilterPostIds = purchasedPostIds

        print("구매 이력 동기화 완료: \(purchasedPostIds.count)/\(filters.count)개 구매")

        // UserDefaults에 저장
        saveToUserDefaults()
    }

    /// 구매 완료 후 호출 (로컬 캐시 업데이트)
    /// - Parameter postId: 구매한 필터의 postId
    func markAsPurchased(postId: String) {
        purchasedFilterPostIds.insert(postId)
        saveToUserDefaults()
    }

    /// 사용 가능한 유료 필터 목록 반환
    func getAvailableFilters() -> [PaidFilter] {
        return availableFilters
    }

    /// 특정 ImageFilter에 해당하는 PaidFilter 찾기
    func getPaidFilter(for imageFilter: ImageFilter) -> PaidFilter? {
        return availableFilters.first { $0.imageFilter == imageFilter }
    }

    // MARK: - Private Methods

    /// UserDefaults에 저장
    private func saveToUserDefaults() {
        let array = Array(purchasedFilterPostIds)
        UserDefaults.standard.set(array, forKey: purchasedFiltersKey)
    }

    /// UserDefaults에서 로드
    private func loadFromUserDefaults() {
        if let array = UserDefaults.standard.array(forKey: purchasedFiltersKey) as? [String] {
            purchasedFilterPostIds = Set(array)
        }
    }
}
