//
//  ChatListFeature.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/11/25.
//

import ComposableArchitecture
import Foundation
import RealmSwift

struct ChatListFeature: Reducer {

    // MARK: - State
    struct State: Equatable {
        var chatRooms: [ChatRoom] = []
        var isLoading: Bool = false
        var myUserId: String?
        @PresentationState var chat: ChatFeature.State?
        @PresentationState var userSearch: UserSearchFeature.State?
        @PresentationState var alert: AlertState<Action.Alert>?
    }

    // MARK: - Action
    @CasePathable
    enum Action: Equatable {
        case onAppear
        case loadMyProfile
        case myProfileLoaded(String)
        case profileLoadFailed(String)
        case loadChatRooms
        case chatRoomsLoaded([ChatRoom])
        case chatRoomsLoadedFromRealm([ChatRoom])
        case chatRoomsLoadFailed
        case chatRoomTapped(ChatRoom)
        case userSearchButtonTapped
        case chat(PresentationAction<ChatFeature.Action>)
        case userSearch(PresentationAction<UserSearchFeature.Action>)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert: Equatable {
            case confirmProfileLoadError
        }
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 채팅 화면이 열려있으면 onAppear 무시 (중복 호출 방지)
                if state.chat != nil {
                    return .none
                }

                state.isLoading = true

                // myUserId는 한 번만 로드, chatRooms는 항상 새로고침
                if state.myUserId == nil {
                    // myUserId 먼저 로드 (순차 실행)
                    return .send(.loadMyProfile)
                } else {
                    // myUserId가 이미 있으면 Realm에서 먼저 로드
                    let userId = state.myUserId!
                    return .run { send in
                        _ = await MainActor.run {
                            do {
                                let realm = try Realm()
                                let chatRoomDTOs = realm.objects(ChatRoomRealmDTO.self)
                                    .filter("myUserId == %@", userId)
                                    .sorted(byKeyPath: "updatedAt", ascending: false)
                                let chatRooms = Array(chatRoomDTOs.map { $0.toDomain })

                                Task {
                                    send(.chatRoomsLoadedFromRealm(chatRooms))
                                    // Realm 로드 후 HTTP로 동기화
                                    send(.loadChatRooms)
                                }
                            } catch {
                                print("Realm 채팅방 로드 실패: \(error)")
                                // Realm 실패 시 HTTP로 직접 로드
                                Task {
                                    send(.loadChatRooms)
                                }
                            }
                        }
                    }
                }

            case .loadMyProfile:
                return .run { send in
                    do {
                        let profile = try await NetworkManager.shared.performRequest(
                            ProfileRouter.lookupMe,
                            as: ProfileDTO.self
                        ).toDomain
                        await send(.myProfileLoaded(profile.userId))
                    } catch {
                        await send(.profileLoadFailed(error.localizedDescription))
                    }
                }

            case .profileLoadFailed(let errorMessage):
                state.isLoading = false
                state.alert = AlertState {
                    TextState("프로필 로드 실패")
                } actions: {
                    ButtonState(role: .cancel, action: .confirmProfileLoadError) {
                        TextState("확인")
                    }
                } message: {
                    TextState(errorMessage)
                }
                return .none

            case .myProfileLoaded(let userId):
                state.myUserId = userId

                // 1. Realm에서 먼저 로드 (빠른 UI 표시)
                return .run { send in
                    _ = await MainActor.run {
                        do {
                            let realm = try Realm()
                            let chatRoomDTOs = realm.objects(ChatRoomRealmDTO.self)
                                .filter("myUserId == %@", userId)
                                .sorted(byKeyPath: "updatedAt", ascending: false)
                            let chatRooms = Array(chatRoomDTOs.map { $0.toDomain })

                            Task {
                                send(.chatRoomsLoadedFromRealm(chatRooms))
                                // 2. Realm 로드 후 HTTP로 동기화
                                send(.loadChatRooms)
                            }
                        } catch {
                            print("Realm 채팅방 로드 실패: \(error)")
                            // Realm 실패 시 HTTP로 직접 로드
                            Task {
                                send(.loadChatRooms)
                            }
                        }
                    }
                }

            case .loadChatRooms:
                return .run { send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            ChatRouter.getChatRoomList,
                            as: ChatRoomListResponseDTO.self
                        )
                        let chatRooms = response.data.map { $0.toDomain }
                        await send(.chatRoomsLoaded(chatRooms))
                    } catch {
                        // HTTP 실패 시 Realm 데이터를 유지 (덮어쓰지 않음)
                        await send(.chatRoomsLoadFailed)
                    }
                }

            case .chatRoomsLoadedFromRealm(let realmChatRooms):
                // Realm에서 로드한 채팅방을 먼저 표시 (빠른 UX)
                state.chatRooms = realmChatRooms
                state.isLoading = true  // HTTP 동기화 중임을 표시
                return .none

            case .chatRoomsLoadFailed:
                // HTTP 실패 시 기존 Realm 데이터 유지하고 로딩만 종료
                state.isLoading = false
                return .none

            case .chatRoomsLoaded(let chatRooms):
                state.chatRooms = chatRooms
                state.isLoading = false

                // Realm에 저장
                guard let myUserId = state.myUserId else {
                    return .none
                }

                return .run { send in
                    _ = await MainActor.run {
                        do {
                            let realm = try Realm()
                            try realm.write {
                                for chatRoom in chatRooms {
                                    let chatRoomDTO = chatRoom.toRealmDTO(myUserId: myUserId)
                                    realm.add(chatRoomDTO, update: .modified)
                                }
                            }
                        } catch {
                            print("Realm 채팅방 저장 실패: \(error)")
                        }
                    }
                }

            case .chatRoomTapped(let chatRoom):
                // 이미 채팅 화면이 열려있으면 무시 (중복 push 방지)
                guard state.chat == nil else {
                    return .none
                }

                // myUserId가 로드되지 않았으면 기다림
                guard let myUserId = state.myUserId else {
                    return .none
                }

                // 상대방 정보 추출
                let opponent: ChatUser
                if let opponentUser = chatRoom.participants.first(where: { $0.userId != myUserId }) {
                    opponent = opponentUser
                } else {
                    // 나 자신과의 채팅방이거나 상대방을 찾을 수 없는 경우 첫 번째 participant 사용
                    opponent = chatRoom.participants.first ?? ChatUser(userId: "", nick: "Unknown", profileImage: nil)
                }

                state.chat = ChatFeature.State(chatRoom: chatRoom, opponent: opponent, myUserId: myUserId)
                return .none

            case .chat(.dismiss):
                state.chat = nil
                // 채팅방 리스트 새로고침하여 최신 메시지 시간 업데이트
                return .send(.loadChatRooms)

            case .chat:
                return .none

            case .userSearchButtonTapped:
                state.userSearch = UserSearchFeature.State(excludeMyself: false)
                return .none

            case .userSearch:
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$chat, action: \.chat) {
            ChatFeature()
        }
        .ifLet(\.$userSearch, action: \.userSearch) {
            UserSearchFeature()
        }
    }
}
