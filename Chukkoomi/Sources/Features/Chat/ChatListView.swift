//
//  ChatListView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/11/25.
//

import SwiftUI
import ComposableArchitecture

struct ChatListView: View {

    let store: StoreOf<ChatListFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
<<<<<<< HEAD

                    // 채팅방 리스트
                    if viewStore.isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if viewStore.chatRooms.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("아직 채팅 내역이 없습니다")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewStore.chatRooms, id: \.roomId) { chatRoom in
                                    Button {
                                        viewStore.send(.chatRoomTapped(chatRoom))
                                    } label: {
                                        ChatRoomRow(chatRoom: chatRoom, myUserId: viewStore.myUserId)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
            }
            .navigationTitle("채팅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewStore.send(.userSearchButtonTapped)
                    } label: {
                        AppIcon.searchUser
                    }
                }
            }
            .navigationDestination(
                store: store.scope(state: \.$chat, action: \.chat)
            ) { chatStore in
                ChatView(store: chatStore)
            }
            .navigationDestination(
                store: store.scope(state: \.$userSearch, action: \.userSearch)
            ) { userSearchStore in
                UserSearchView(store: userSearchStore)
            }
=======
                // 상단 타이틀
                Text("채팅")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

                // 채팅방 리스트
                if viewStore.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewStore.chatRooms.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("아직 채팅 내역이 없습니다")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewStore.chatRooms, id: \.roomId) { chatRoom in
                                ChatRoomRow(chatRoom: chatRoom)
                                    .onTapGesture {
                                        viewStore.send(.chatRoomTapped(chatRoom))
                                    }
                            }
                        }
                    }
                }
            }
>>>>>>> 34c0a81 (feat: 채팅 리스트 화면 구현 및 탭바 연결)
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

// MARK: - 채팅방 Row
struct ChatRoomRow: View {

    let chatRoom: ChatRoom
<<<<<<< HEAD
    let myUserId: String?
=======
>>>>>>> 34c0a81 (feat: 채팅 리스트 화면 구현 및 탭바 연결)

    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
<<<<<<< HEAD
            if let profileImagePath = opponentProfileImage {
                AsyncMediaImageView(
                    imagePath: profileImagePath,
                    width: 56,
                    height: 56
                )
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .overlay {
                        AppIcon.personFill
                            .foregroundColor(.gray)
                            .font(.system(size: 28))
                    }
            }

            // 닉네임 + 마지막 메시지
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isMyself {
                        Circle()
                            .fill(AppColor.disabled)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text("나")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }

                    Text(opponentNickname)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
=======
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 56, height: 56)
                .overlay(
                    // TODO: 실제 프로필 이미지 로드
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                )

            // 닉네임 + 마지막 메시지
            VStack(alignment: .leading, spacing: 4) {
                Text(opponentNickname)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
>>>>>>> 34c0a81 (feat: 채팅 리스트 화면 구현 및 탭바 연결)

                if let lastMessage = chatRoom.lastChat?.content {
                    Text(lastMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                } else if let lastChat = chatRoom.lastChat, !lastChat.files.isEmpty {
                    Text("사진")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                } else {
                    Text("메시지를 시작해보세요")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }

            Spacer()

            // 시간 + 안읽은 메시지 뱃지
            VStack(alignment: .trailing, spacing: 4) {
                if let lastChat = chatRoom.lastChat {
<<<<<<< HEAD
                    Text(DateFormatters.formatChatListDate(lastChat.createdAt))
=======
                    Text(formatDate(lastChat.createdAt))
>>>>>>> 34c0a81 (feat: 채팅 리스트 화면 구현 및 탭바 연결)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                // TODO: 안읽은 메시지 개수 표시
//                if unreadCount > 0 {
//                    Text("\(unreadCount)")
//                        .font(.system(size: 11, weight: .semibold))
//                        .foregroundColor(.white)
//                        .padding(.horizontal, 6)
//                        .padding(.vertical, 2)
//                        .background(Color.red)
//                        .clipShape(Capsule())
//                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

<<<<<<< HEAD
    // 나 자신과의 대화인지 확인
    private var isMyself: Bool {
        guard let myUserId = myUserId else {
            return false
        }

        // 모든 participant가 나인 경우 (나와의 채팅방)
        return chatRoom.participants.allSatisfy { $0.userId == myUserId }
    }

    // 상대방 닉네임 추출 (1:1 채팅이므로 본인 제외)
    private var opponentNickname: String {
        guard let myUserId = myUserId else {
            return chatRoom.participants.first?.nick ?? "알 수 없음"
        }

        // 내가 아닌 participant 찾기
        if let opponent = chatRoom.participants.first(where: { $0.userId != myUserId }) {
            return opponent.nick
        }

        // 나 자신과의 채팅방인 경우 (모든 participant가 나)
        return chatRoom.participants.first?.nick ?? "알 수 없음"
    }

    // 상대방 프로필 이미지 추출
    private var opponentProfileImage: String? {
        guard let myUserId = myUserId else {
            return chatRoom.participants.first?.profileImage
        }

        // 내가 아닌 participant 찾기
        if let opponent = chatRoom.participants.first(where: { $0.userId != myUserId }) {
            return opponent.profileImage
        }

        // 나 자신과의 채팅방인 경우
        return chatRoom.participants.first?.profileImage
=======
    // 상대방 닉네임 추출 (1:1 채팅이므로 본인 제외)
    private var opponentNickname: String {
        // TODO: 현재 로그인한 사용자 ID와 비교해서 상대방 찾기
        // 임시로 첫 번째 participant 사용
        return chatRoom.participants.first?.nick ?? "알 수 없음"
    }

    // 날짜 포맷 (간단하게)
    private func formatDate(_ dateString: String) -> String {
        // TODO: ISO 8601 날짜를 "오전 10:30" 형식으로 변환
        // 임시로 시간만 추출
        let components = dateString.split(separator: "T")
        if components.count > 1 {
            let timeString = String(components[1].prefix(5))
            return timeString
        }
        return ""
>>>>>>> 34c0a81 (feat: 채팅 리스트 화면 구현 및 탭바 연결)
    }
}
