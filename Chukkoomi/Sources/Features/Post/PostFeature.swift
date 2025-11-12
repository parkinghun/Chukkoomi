//
//  PostFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import ComposableArchitecture
import SwiftUI

struct PostFeature: Reducer {

    // MARK: - State
    struct State: Equatable {
        var posts: [Post] = []
        var isLoading: Bool = false

        init() {
            self.loadMockData()
        }

        private mutating func loadMockData() {
            // 목업 데이터
            posts = [
                Post(
                    teams: .total,
                    title: "즐겁게 이겨 안보면 바보",
                    price: 0,
                    content: "2025시즌 K리그 1 2라운드 리뷰",
                    files: ["mock_image_1"]
                ),
                Post(
                    teams: .total,
                    title: "2025년 K리그 여름 이적시장 정리",
                    price: 0,
                    content: "여름 이적시장 정리",
                    files: ["mock_image_2"]
                )
            ]
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case loadPosts
        case postTapped(String) // post ID
        case likeTapped(String) // post ID
        case commentTapped(String) // post ID
        case shareTapped(String) // post ID
        case followTapped(String) // user ID
    }

    // MARK: - Reducer
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .send(.loadPosts)

        case .loadPosts:
            // TODO: API 호출
            print("📱 게시글 로드")
            return .none

        case let .postTapped(postId):
            print("📄 게시글 탭: \(postId)")
            return .none

        case let .likeTapped(postId):
            print("❤️ 좋아요 탭: \(postId)")
            return .none

        case let .commentTapped(postId):
            print("💬 댓글 탭: \(postId)")
            return .none

        case let .shareTapped(postId):
            print("📤 공유 탭: \(postId)")
            return .none

        case let .followTapped(userId):
            print("➕ 팔로우 탭: \(userId)")
            return .none
        }
    }
}
