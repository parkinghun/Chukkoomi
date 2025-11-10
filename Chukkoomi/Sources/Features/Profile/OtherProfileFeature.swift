//
//  OtherProfileFeature.swift
//  Chukkoomi
//
//  Created by Claude on 11/7/25.
//

import ComposableArchitecture
import Foundation

struct OtherProfileFeature: Reducer {

    // MARK: - State
    struct State: Equatable {
        var userId: String
        var myUser: User?
        var profile: Profile?
        var postImages: [PostImage] = []
        var isLoading: Bool = false
        var profileImageData: Data?
        var isFollowing: Bool = false

        // Computed properties
        var nickname: String {
            profile?.nickname ?? ""
        }

        var introduce: String {
            profile?.introduce ?? ""
        }

        var postCount: Int {
            profile?.posts.count ?? 0
        }

        var followerCount: Int {
            profile?.followers.count ?? 0
        }

        var followingCount: Int {
            profile?.following.count ?? 0
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case followButtonTapped
        case messageButtonTapped

        // API 응답
        case myProfileLoaded(Profile)
        case profileLoaded(Profile)
        case postImagesLoaded([PostImage])
        case profileImageLoaded(Data)
        case followToggled(Bool)
        case postImageDownloaded(id: String, data: Data)

        // 게시물 fetch
        case fetchPosts(postIds: [String])
        case fetchProfileImage(path: String)
        case fetchPostImage(id: String, path: String)
    }

    // MARK: - Reducer
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isLoading = true
            return .run { [userId = state.userId] send in
                do {
                    // 내 프로필과 다른 사람 프로필 병렬로 조회
                    async let myProfile = NetworkManager.shared.performRequest(
                        ProfileRouter.lookupMe,
                        as: ProfileDTO.self
                    ).toDomain

                    async let otherProfile = NetworkManager.shared.performRequest(
                        ProfileRouter.lookupOther(id: userId),
                        as: ProfileDTO.self
                    ).toDomain

                    let (my, other) = try await (myProfile, otherProfile)
                    await send(.myProfileLoaded(my))
                    await send(.profileLoaded(other))
                } catch {
                    // TODO: 에러 처리
                    print("프로필 로드 실패: \(error)")
                }
            }

        case .followButtonTapped:
            return .run { [userId = state.userId, isFollowing = state.isFollowing] send in
                do {
                    let response = try await NetworkManager.shared.performRequest(
                        FollowRouter.follow(id: userId, follow: !isFollowing),
                        as: FollowResponseDTO.self
                    ).toDomain
                    await send(.followToggled(response.status))
                } catch {
                    print("팔로우 토글 실패: \(error)")
                }
            }

        case .messageButtonTapped:
            // TODO: 메시지 화면으로 이동
            return .none

        case .myProfileLoaded(let myProfile):
            state.myUser = User(
                userId: myProfile.userId,
                nickname: myProfile.nickname,
                profileImage: myProfile.profileImage
            )
            // 다른 사람 프로필이 이미 로드되었으면 팔로우 상태 확인
            if let profile = state.profile, let myUser = state.myUser {
                state.isFollowing = profile.followers.contains { $0.userId == myUser.userId }
            }
            return .none

        case .profileLoaded(let profile):
            state.profile = profile
            state.isLoading = false

            // 내 userId가 있으면 팔로우 상태 확인
            if let myUser = state.myUser {
                state.isFollowing = profile.followers.contains { $0.userId == myUser.userId }
            }

            // 프로필 이미지와 게시물 fetch
            if let imagePath = profile.profileImage {
                return .merge(
                    .send(.fetchProfileImage(path: imagePath)),
                    .send(.fetchPosts(postIds: profile.posts))
                )
            } else {
                return .send(.fetchPosts(postIds: profile.posts))
            }

        case .postImagesLoaded(let images):
            state.postImages = images
            // 각 이미지 다운로드
            let effects = images.map { image in
                Effect<Action>.send(.fetchPostImage(id: image.id, path: image.imagePath))
            }
            return .merge(effects)

        case .profileImageLoaded(let data):
            state.profileImageData = data
            return .none

        case .followToggled(let isFollowing):
            state.isFollowing = isFollowing

            // 팔로워 숫자 즉시 업데이트
            guard var profile = state.profile, let myUser = state.myUser else {
                return .none
            }

            if isFollowing {
                // 팔로우: followers 배열에 내 정보 추가
                if !profile.followers.contains(where: { $0.userId == myUser.userId }) {
                    profile.followers.append(myUser)
                    state.profile = profile
                }
            } else {
                // 언팔로우: followers 배열에서 내 정보 제거
                profile.followers.removeAll { $0.userId == myUser.userId }
                state.profile = profile
            }

            return .none

        case .postImageDownloaded(let id, let data):
            if let index = state.postImages.firstIndex(where: { $0.id == id }) {
                state.postImages[index].imageData = data
            }
            return .none

        case .fetchProfileImage(let path):
            return .run { send in
                do {
                    let imageData = try await NetworkManager.shared.download(
                        MediaRouter.getData(path: path)
                    )
                    await send(.profileImageLoaded(imageData))
                } catch {
                    print("프로필 이미지 로드 실패: \(error)")
                }
            }

        case .fetchPostImage(let id, let path):
            return .run { send in
                do {
                    let imageData = try await NetworkManager.shared.download(
                        MediaRouter.getData(path: path)
                    )
                    await send(.postImageDownloaded(id: id, data: imageData))
                } catch {
                    print("게시글 이미지 로드 실패: \(error)")
                }
            }

        case .fetchPosts(let postIds):
            // TODO: postIds로 게시물 데이터 fetch 후 PostImage 배열로 변환
            return .none
        }
    }
}

// MARK: - Models
extension OtherProfileFeature {
    // 게시글 그리드에 표시할 이미지 정보
    struct PostImage: Equatable, Identifiable {
        let id: String
        let imagePath: String
        var imageData: Data?
    }
}
