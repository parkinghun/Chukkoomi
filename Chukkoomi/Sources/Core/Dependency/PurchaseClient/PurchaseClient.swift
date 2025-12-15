//
//  PurchaseClient.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.
//

import ComposableArchitecture
import Foundation

/// 필터 구매 이력 관리를 담당하는 Dependency
@DependencyClient
struct PurchaseClient {
    var isPurchased: @Sendable (_ filter: ImageFilter) async -> Bool = { _ in false }
    /// 서버에서 구매 이력 동기화
    var syncPurchaseHistory: @Sendable () async throws -> Void

    /// 구매 완료 후 호출 (로컬 캐시 업데이트)
    var markAsPurchased: @Sendable (_ postId: String) async -> Void

    /// 사용 가능한 유료 필터 목록 반환
    var getAvailableFilters: @Sendable () async -> [PaidFilter] = { [] }

    /// 특정 ImageFilter에 해당하는 PaidFilter 찾기
    var getPaidFilter: @Sendable (_ imageFilter: ImageFilter) async -> PaidFilter? = { _ in nil }
}

// MARK: - DependencyKey

extension PurchaseClient: DependencyKey {
    static let liveValue: PurchaseClient = {
        let manager = PurchaseManager.shared

        return PurchaseClient(
            isPurchased: { filter in
                await manager.isPurchased(filter)
            },
            syncPurchaseHistory: {
                try await manager.syncPurchaseHistory()
            },
            markAsPurchased: { postId in
                await manager.markAsPurchased(postId: postId)
            },
            getAvailableFilters: {
                await manager.getAvailableFilters()
            },
            getPaidFilter: { imageFilter in
                await manager.getPaidFilter(for: imageFilter)
            }
        )
    }()

    /// 테스트용 Mock 구현
    static let testValue: PurchaseClient = PurchaseClient(
        isPurchased: { _ in false },
        syncPurchaseHistory: {},
        markAsPurchased: { _ in },
        getAvailableFilters: { [] },
        getPaidFilter: { _ in nil }
    )

    /// Preview용 Mock 구현 (구매된 상태 시뮬레이션)
    static let previewValue: PurchaseClient = PurchaseClient(
        isPurchased: { filter in
            // Preview에서는 모든 필터를 구매된 것으로 표시
            true
        },
        syncPurchaseHistory: {},
        markAsPurchased: { _ in },
        getAvailableFilters: {
            // Mock 필터 목록 반환
            []
        },
        getPaidFilter: { _ in nil }
    )
}

// MARK: - DependencyValues Extension

extension DependencyValues {
    var purchase: PurchaseClient {
        get { self[PurchaseClient.self] }
        set { self[PurchaseClient.self] = newValue }
    }
}
