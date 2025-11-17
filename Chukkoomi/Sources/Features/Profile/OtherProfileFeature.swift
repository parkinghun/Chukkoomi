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
        var isFollowing: Bool = false

        @PresentationState var followList: FollowListFeature.State?
        @PresentationState var chat: ChatFeature.State?

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
        case followToggled(Bool)
        case chatRoomChecked(ChatRoom?)

        // 게시물 fetch
        case fetchPosts(postIds: [String])

        // Navigation
        case followList(PresentationAction<FollowListFeature.Action>)
        case chat(PresentationAction<ChatFeature.Action>)
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
            // 기존 채팅방이 있는지 확인하기 위해 채팅방 리스트 조회
            guard let profile = state.profile else { return .none }

            return .run { [userId = profile.userId, myUserId = state.myUser?.userId] send in
                do {
                    let response = try await NetworkManager.shared.performRequest(
                        ChatRouter.getChatRoomList,
                        as: ChatRoomListResponseDTO.self
                    )
                    let chatRooms = response.data.map { $0.toDomain }

                    // 해당 사용자와의 기존 채팅방 찾기
                    let existingChatRoom = chatRooms.first { chatRoom in
                        // 1:1 채팅방만 확인
                        guard chatRoom.participants.count == 2 else { return false }

                        // 자신과의 채팅방인 경우
                        if userId == myUserId {
                            // 모든 participants가 자신인 채팅방
                            return chatRoom.participants.allSatisfy { $0.userId == myUserId }
                        }

                        // 다른 사람과의 채팅방: participants에 상대방과 자신이 모두 포함
                        return chatRoom.participants.contains { $0.userId == userId } &&
                               chatRoom.participants.contains { $0.userId == myUserId }
                    }

                    await send(.chatRoomChecked(existingChatRoom))
                } catch {
                    // 에러 발생 시에도 채팅방 없는 것으로 처리
                    await send(.chatRoomChecked(nil))
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

            return .send(.fetchPosts(postIds: profile.posts))

        case .postImagesLoaded(let images):
            state.postImages = images
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

        case .chatRoomChecked(let existingChatRoom):
            // 채팅 화면으로 이동 (기존 채팅방이 있으면 사용, 없으면 첫 메시지 전송 시 생성)
            guard let profile = state.profile else { return .none }

            let opponent = ChatUser(
                userId: profile.userId,
                nick: profile.nickname,
                profileImage: profile.profileImage
            )

            state.chat = ChatFeature.State(
                chatRoom: existingChatRoom,
                opponent: opponent,
                myUserId: state.myUser?.userId
            )
            return .none

        case .fetchPosts(let postIds):
            // TODO: postIds로 게시물 데이터 fetch 후 PostImage 배열로 변환
            return .none

        case .followList:
            return .none

        case .chat:
            return .none
        }
        }
        .ifLet(\.$followList, action: \.followList) {
            FollowListFeature()
        }
        .ifLet(\.$chat, action: \.chat) {
            ChatFeature()
        }
    }
}

// MARK: - Models
extension OtherProfileFeature {
    // 게시글 그리드에 표시할 미디어 정보
    struct PostImage: Equatable, Identifiable {
        let id: String
        let imagePath: String
        let isVideo: Bool

        init(id: String, imagePath: String) {
            self.id = id
            self.imagePath = imagePath
            self.isVideo = MediaTypeHelper.isVideoPath(imagePath)
        }
    }
}
