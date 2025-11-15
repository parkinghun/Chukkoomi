//
//  ChatView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/12/25.
//

import SwiftUI
import ComposableArchitecture

struct ChatView: View {

    let store: StoreOf<ChatFeature>
    @State private var opponentProfileImage: UIImage?

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // onAppear 트리거용 투명 뷰
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        viewStore.send(.onAppear)
                    }
                    .task {
                        // 프로필 이미지 한 번만 로드
                        await loadOpponentProfileImage(
                            chatRoom: viewStore.chatRoom,
                            myUserId: viewStore.myUserId
                        )
                    }

                // 메시지 리스트
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // 페이지네이션 로딩 인디케이터
                            if viewStore.isLoading && viewStore.cursorDate != nil {
                                ProgressView()
                                    .padding(.vertical, 8)
                            }

                            // 메시지 목록
                            ForEach(Array(viewStore.messages.enumerated()), id: \.element.chatId) { index, message in
                                // 날짜 구분선 표시 (첫 메시지이거나 이전 메시지와 날짜가 다를 때)
                                if index == 0 || shouldShowDateSeparator(currentMessage: message, previousMessage: viewStore.messages[index - 1]) {
                                    DateSeparatorView(dateString: message.createdAt)
                                        .padding(.vertical, 12)
                                }

                                MessageRow(
                                    message: message,
                                    isMyMessage: isMyMessage(message, myUserId: viewStore.myUserId),
                                    opponentProfileImage: opponentProfileImage
                                )
                                .id(message.chatId)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewStore.messages.count) {
                        // 새 메시지가 추가되면 스크롤을 최하단으로
                        if let lastMessage = viewStore.messages.last {
                            withAnimation {
                                scrollProxy.scrollTo(lastMessage.chatId, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        // 초기 로드 후 스크롤을 최하단으로
                        if let lastMessage = viewStore.messages.last {
                            scrollProxy.scrollTo(lastMessage.chatId, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // 메시지 입력창
                HStack(spacing: 12) {
                    TextField("메시지를 입력하세요", text: viewStore.binding(
                        get: \.messageText,
                        send: { .messageTextChanged($0) }
                    ))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)

                    Button(action: {
                        viewStore.send(.sendMessageTapped)
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(viewStore.messageText.isEmpty ? .gray : .blue)
                            .font(.system(size: 20))
                    }
                    .disabled(viewStore.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewStore.isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle(opponentNickname(chatRoom: viewStore.chatRoom, myUserId: viewStore.myUserId))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // 현재 사용자의 메시지인지 확인
    private func isMyMessage(_ message: ChatMessage, myUserId: String?) -> Bool {
        guard let myUserId = myUserId else {
            return false
        }
        return message.sender.userId == myUserId
    }

    // 상대방 닉네임 추출
    private func opponentNickname(chatRoom: ChatRoom, myUserId: String?) -> String {
        guard let myUserId = myUserId else {
            return chatRoom.participants.first?.nick ?? "채팅"
        }

        // 내가 아닌 participant 찾기
        if let opponent = chatRoom.participants.first(where: { $0.userId != myUserId }) {
            return opponent.nick
        }

        // 나 자신과의 채팅방인 경우 (모든 participant가 나)
        return chatRoom.participants.first?.nick ?? "채팅"
    }

    // 날짜 구분선을 표시할지 확인
    private func shouldShowDateSeparator(currentMessage: ChatMessage, previousMessage: ChatMessage) -> Bool {
        return DateFormatters.isDifferentDay(previousMessage.createdAt, currentMessage.createdAt)
    }

    // 상대방 프로필 이미지를 한 번만 로드
    private func loadOpponentProfileImage(chatRoom: ChatRoom, myUserId: String?) async {
        let imagePath: String?

        if let myUserId = myUserId,
           let opponent = chatRoom.participants.first(where: { $0.userId != myUserId }) {
            imagePath = opponent.profileImage
        } else {
            imagePath = chatRoom.participants.first?.profileImage
        }

        guard let path = imagePath else {
            return
        }

        do {
            let imageData: Data

            if path.hasPrefix("http://") || path.hasPrefix("https://") {
                guard let url = URL(string: path) else { return }
                let (data, _) = try await URLSession.shared.data(from: url)
                imageData = data
            } else {
                imageData = try await NetworkManager.shared.download(
                    MediaRouter.getData(path: path)
                )
            }

            if let uiImage = UIImage(data: imageData) {
                opponentProfileImage = uiImage
            }
        } catch {
            // 프로필 이미지 로드 실패 시 기본 아이콘 표시
        }
    }
}

// MARK: - 날짜 구분선
struct DateSeparatorView: View {
    let dateString: String

    var body: some View {
        Text(DateFormatters.formatChatDateSeparator(dateString))
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.6))
            .cornerRadius(12)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - 메시지 Row
struct MessageRow: View {

    let message: ChatMessage
    let isMyMessage: Bool
    let opponentProfileImage: UIImage?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMyMessage {
                Spacer(minLength: 60)

                // 내 메시지: 시간이 왼쪽
                Text(DateFormatters.formatChatMessageTime(message.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                messageContent
            } else {
                // 상대방 프로필 이미지
                if let profileImage = opponentProfileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        )
                }

                messageContent

                // 받은 메시지: 시간이 오른쪽
                Text(DateFormatters.formatChatMessageTime(message.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                Spacer(minLength: 60)
            }
        }
    }

    // 메시지 내용 부분
    private var messageContent: some View {
        VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 4) {
            // 메시지 내용
            if let content = message.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 15))
                    .foregroundColor(isMyMessage ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMyMessage ? Color.blue : Color.gray.opacity(0.2))
                    .cornerRadius(16)
            }

            // 이미지 파일
            if !message.files.isEmpty {
                ForEach(message.files, id: \.self) { fileUrl in
                    AsyncImage(url: URL(string: fileUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(12)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 200, height: 200)
                            .cornerRadius(12)
                            .overlay(
                                ProgressView()
                            )
                    }
                }
            }
        }
    }
}
