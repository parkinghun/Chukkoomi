//
//  PaidFilter.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/26/25.
//

import Foundation

/// 유료 필터 정보
struct PaidFilter: Equatable, Identifiable {
    let id: String  // post_id
    let title: String
    let price: Int
    let content: String
    let imageFilter: ImageFilter

    /// 서버에서 받은 Post를 PaidFilter로 변환
    static func from(post: Post) -> PaidFilter? {
        // title로 ImageFilter 매핑
        let imageFilter: ImageFilter

        if post.title.contains("애니메이션") {
            imageFilter = .animeGANHayao
        } else if post.title.contains("스케치") {
            imageFilter = .anime2sketch
        } else {
            return nil
        }

        return PaidFilter(
            id: post.id,
            title: post.title,
            price: post.price,
            content: post.content,
            imageFilter: imageFilter
        )
    }
}

extension ImageFilter {
    /// 유료 필터 여부
    var isPaid: Bool {
        switch self {
        case .animeGANHayao, .anime2sketch:
            return true
        default:
            return false
        }
    }
}
