//
//  OtherProfileFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/7/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct OtherProfileFeature {

    // MARK: - State
    struct State: Equatable {
        var userId: String
        var myUser: User?
        var profile: Profile?
        var postImages: [PostImage] = []
        var isLoading: Bool = false
        var profileImageData: Data?
        var isFollowing: Bool = false

        @PresentationState var followList: FollowListFeature.State?

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
        case followerButtonTapped
        case followingButtonTapped

        // API 응답
        case myProfileLoaded(Profile)
        case profileLoaded(Profile)
        case postImagesLoaded([PostImage])
        case profileImageLoaded(Data)
        case followToggled(Bool)
        case postImageDownloaded(id: String, data: Data, isVideo: Bool)
        case chatRoomCreated(ChatRoom)

        // 게시물 fetch
        case fetchPosts(postIds: [String])
        case fetchProfileImage(path: String)
        case fetchPostImage(id: String, path: String, isVideo: Bool)

        // Navigation
        case followList(PresentationAction<FollowListFeature.Action>)
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
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
            // 채팅방 생성
            return .run { [userId = state.userId] send in
                do {
                    let response = try await NetworkManager.shared.performRequest(
                        ChatRouter.createChatRoom(opponentId: userId),
                        as: ChatRoomResponseDTO.self
                    )
                    let chatRoom = response.toDomain
                    await send(.chatRoomCreated(chatRoom))
                } catch {
                    print("채팅방 생성 실패: \(error)")
                    // TODO: 채팅방 화면 구현되면 네비게이션으로 변경
                }
            }

        case .followerButtonTapped:
            guard let profile = state.profile else { return .none }
            state.followList = FollowListFeature.State(
                listType: .followers(users: profile.followers)
            )
            return .none

        case .followingButtonTapped:
            guard let profile = state.profile else { return .none }
            state.followList = FollowListFeature.State(
                listType: .following(users: profile.following)
            )
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
                Effect<Action>.send(.fetchPostImage(id: image.id, path: image.imagePath, isVideo: image.isVideo))
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

        case .postImageDownloaded(let id, let data, let isVideo):
            if let index = state.postImages.firstIndex(where: { $0.id == id }) {
                if isVideo {
                    // 동영상이면 썸네일 추출
                    return .run { send in
                        if let thumbnailData = await VideoThumbnailHelper.generateThumbnail(from: data) {
                            await send(.postImageDownloaded(id: id, data: thumbnailData, isVideo: false))
                        }
                    }
                } else {
                    state.postImages[index].imageData = data
                }
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

        case .fetchPostImage(let id, let path, let isVideo):
            return .run { send in
                do {
                    let mediaData = try await NetworkManager.shared.download(
                        MediaRouter.getData(path: path)
                    )
                    await send(.postImageDownloaded(id: id, data: mediaData, isVideo: isVideo))
                } catch {
                    print("게시글 미디어 로드 실패: \(error)")
                }
            }

        case .chatRoomCreated(let chatRoom):
            // 채팅방 생성 성공
            print("채팅방 생성 성공: \(chatRoom.roomId)")
            // TODO: 채팅방 화면으로 네비게이션
            return .none

        case .fetchPosts(let postIds):
            // TODO: postIds로 게시물 데이터 fetch 후 PostImage 배열로 변환
            return .none

        case .followList:
            return .none
        }
        }
        .ifLet(\.$followList, action: \.followList) {
            FollowListFeature()
        }
    }
}

// MARK: - Models
extension OtherProfileFeature {
    // 게시글 그리드에 표시할 미디어 정보
    struct PostImage: Equatable, Identifiable {
        let id: String
        let imagePath: String
        var imageData: Data?
        let isVideo: Bool

        init(id: String, imagePath: String, imageData: Data? = nil) {
            self.id = id
            self.imagePath = imagePath
            self.imageData = imageData
            self.isVideo = MediaTypeHelper.isVideoPath(imagePath)
        }
    }
}
