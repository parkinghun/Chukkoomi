//
//  FilterCacheClient.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.
//

import ComposableArchitecture
import Foundation
import UIKit

/// 필터 이미지 캐싱을 담당하는 Dependency
@DependencyClient
struct FilterCacheClient {
    var getThumbnail: @Sendable (_ key: String) -> UIImage?
    var setThumbnail: @Sendable (_ image: UIImage, _ key: String) -> Void
    var getFullImage: @Sendable (_ key: String) -> UIImage?
    var setFullImage: @Sendable (_ image: UIImage, _ key: String) -> Void
    var clearAll: @Sendable () -> Void  // 모든 캐시 삭제
    var clearThumbnailCache: @Sendable () -> Void
    var clearFullImageCache: @Sendable () -> Void
    var handleMemoryWarning: @Sendable () -> Void
}

// MARK: - DependencyKey

extension FilterCacheClient: DependencyKey {
    static let liveValue: FilterCacheClient = {
        let manager = FilterCacheManager()

        return FilterCacheClient(
            getThumbnail: { key in
                manager.getThumbnail(for: key)
            },
            setThumbnail: { image, key in
                manager.setThumbnail(image, for: key)
            },
            getFullImage: { key in
                manager.getFullImage(for: key)
            },
            setFullImage: { image, key in
                manager.setFullImage(image, for: key)
            },
            clearAll: {
                manager.clearAll()
            },
            clearThumbnailCache: {
                manager.clearThumbnailCache()
            },
            clearFullImageCache: {
                manager.clearFullImageCache()
            },
            handleMemoryWarning: {
                manager.handleMemoryWarning()
            }
        )
    }()

    /// 테스트용 Mock 구현
    static let testValue: FilterCacheClient = FilterCacheClient(
        getThumbnail: { _ in nil },
        setThumbnail: { _, _ in },
        getFullImage: { _ in nil },
        setFullImage: { _, _ in },
        clearAll: {},
        clearThumbnailCache: {},
        clearFullImageCache: {},
        handleMemoryWarning: {}
    )
}

// MARK: - DependencyValues Extension

extension DependencyValues {
    var filterCache: FilterCacheClient {
        get { self[FilterCacheClient.self] }
        set { self[FilterCacheClient.self] = newValue }
    }
}
