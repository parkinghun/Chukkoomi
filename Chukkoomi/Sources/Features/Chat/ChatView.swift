//
//  ChatView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/12/25.
//

import SwiftUI
import ComposableArchitecture
import PhotosUI
import UniformTypeIdentifiers

struct ChatView: View {

    let store: StoreOf<ChatFeature>
    @State private var opponentProfileImage: UIImage?
    @State private var selectedPhotosItems: [PhotosPickerItem] = []
    @State private var isProcessingPhotos: Bool = false

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
                            opponent: viewStore.opponent
                        )
                    }

                // 메시지 리스트
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // 페이지네이션 로딩 인디케이터
                            if viewStore.isLoading && viewStore.cursorDate != nil {
                                ProgressView()
                                    .padding(.vertical, 8)
                            }

                            // 메시지 목록
                            ForEach(Array(viewStore.messages.enumerated()), id: \.element.chatId) { index, message in
                                let isAfterDateSeparator = index == 0 || shouldShowDateSeparator(currentMessage: message, previousMessage: viewStore.messages[index - 1])

                                // 날짜 구분선 표시 (첫 메시지이거나 이전 메시지와 날짜가 다를 때)
                                if isAfterDateSeparator {
                                    DateSeparatorView(dateString: message.createdAt)
                                        .padding(.top, 16)
                                        .padding(.bottom, 16)
                                }

                                let previousMessage = index > 0 ? viewStore.messages[index - 1] : nil
                                let nextMessage = index < viewStore.messages.count - 1 ? viewStore.messages[index + 1] : nil

                                MessageRow(
                                    message: message,
                                    isMyMessage: isMyMessage(message, myUserId: viewStore.myUserId),
                                    opponentProfileImage: opponentProfileImage,
                                    showProfile: shouldShowProfile(currentMessage: message, previousMessage: previousMessage, myUserId: viewStore.myUserId),
                                    showTime: shouldShowTime(currentMessage: message, nextMessage: nextMessage, myUserId: viewStore.myUserId)
                                )
                                .id(message.chatId)
                                .padding(.top, isAfterDateSeparator ? 0 : (isNewMessageGroup(currentMessage: message, previousMessage: previousMessage) ? 8 : 2))
                                .padding(.bottom, index == viewStore.messages.count - 1 ? 8 : 0)
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
                    // 이미지/영상 선택 버튼
                    PhotosPicker(selection: $selectedPhotosItems, maxSelectionCount: 5, matching: .any(of: [.images, .videos])) {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                            .font(.system(size: 22))
                    }
                    .onChange(of: selectedPhotosItems) { oldValue, newValue in
                        handlePhotosSelection(newValue: newValue, viewStore: viewStore)
                    }
                    .disabled(viewStore.isUploadingFiles || isProcessingPhotos)

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
                            .foregroundColor(viewStore.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                            .font(.system(size: 20))
                    }
                    .disabled(viewStore.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewStore.isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay {
                    // 업로드 중 로딩 표시
                    if viewStore.isUploadingFiles {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.1))
                    }
                }
            }
            .navigationTitle(opponentNickname(chatRoom: viewStore.chatRoom, opponent: viewStore.opponent, myUserId: viewStore.myUserId))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
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
    private func opponentNickname(chatRoom: ChatRoom?, opponent: ChatUser, myUserId: String?) -> String {
        guard let chatRoom = chatRoom else {
            // 채팅방이 아직 생성되지 않은 경우 opponent 정보 사용
            return opponent.nick
        }

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

    // 두 메시지가 같은 분에 보낸 메시지인지 확인
    private func isSameMinute(_ message1: ChatMessage, _ message2: ChatMessage) -> Bool {
        guard let date1 = DateFormatters.parseDate(message1.createdAt),
              let date2 = DateFormatters.parseDate(message2.createdAt) else {
            return false
        }

        let calendar = Calendar.current
        let components1 = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date1)
        let components2 = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date2)

        return components1.year == components2.year &&
               components1.month == components2.month &&
               components1.day == components2.day &&
               components1.hour == components2.hour &&
               components1.minute == components2.minute
    }

    // 프로필 이미지와 닉네임을 표시할지 확인
    private func shouldShowProfile(currentMessage: ChatMessage, previousMessage: ChatMessage?, myUserId: String?) -> Bool {
        // 첫 메시지거나 이전 메시지가 없으면 표시
        guard let previousMessage = previousMessage else {
            return true
        }

        // 내 메시지면 항상 프로필 숨김
        if isMyMessage(currentMessage, myUserId: myUserId) {
            return false
        }

        // 파일이 있으면 항상 표시
        if !currentMessage.files.isEmpty {
            return true
        }

        // 이전 메시지가 파일이었으면 표시
        if !previousMessage.files.isEmpty {
            return true
        }

        // 발신자가 다르면 표시
        if currentMessage.sender.userId != previousMessage.sender.userId {
            return true
        }

        // 같은 발신자이지만 시간이 다르면 표시
        if !isSameMinute(currentMessage, previousMessage) {
            return true
        }

        // 같은 발신자, 같은 시간이면 숨김
        return false
    }

    // 시간을 표시할지 확인
    private func shouldShowTime(currentMessage: ChatMessage, nextMessage: ChatMessage?, myUserId: String?) -> Bool {
        // 다음 메시지가 없으면 표시
        guard let nextMessage = nextMessage else {
            return true
        }

        // 파일이 있으면 항상 표시
        if !currentMessage.files.isEmpty {
            return true
        }

        // 다음 메시지가 파일이면 표시
        if !nextMessage.files.isEmpty {
            return true
        }

        // 발신자가 다르면 표시
        if currentMessage.sender.userId != nextMessage.sender.userId {
            return true
        }

        // 같은 발신자이지만 시간이 다르면 표시
        if !isSameMinute(currentMessage, nextMessage) {
            return true
        }

        // 같은 발신자, 같은 시간이면 숨김
        return false
    }

    // 새로운 메시지 그룹인지 확인 (간격 조절용)
    private func isNewMessageGroup(currentMessage: ChatMessage, previousMessage: ChatMessage?) -> Bool {
        // 첫 메시지면 새 그룹
        guard let previousMessage = previousMessage else {
            return true
        }

        // 현재 또는 이전 메시지가 파일이 있으면 새 그룹
        if !currentMessage.files.isEmpty || !previousMessage.files.isEmpty {
            return true
        }

        // 발신자가 다르면 새 그룹
        if currentMessage.sender.userId != previousMessage.sender.userId {
            return true
        }

        // 같은 발신자이지만 시간이 다르면 새 그룹
        if !isSameMinute(currentMessage, previousMessage) {
            return true
        }

        // 같은 발신자, 같은 시간이면 같은 그룹
        return false
    }

    // 상대방 프로필 이미지를 한 번만 로드
    private func loadOpponentProfileImage(opponent: ChatUser) async {
        guard let path = opponent.profileImage else {
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

    // 사진/영상 선택 처리
    private func handlePhotosSelection(newValue: [PhotosPickerItem], viewStore: ViewStoreOf<ChatFeature>) {
        guard !newValue.isEmpty, !isProcessingPhotos else { return }

        // 즉시 초기화해서 중복 트리거 방지
        let itemsToProcess = newValue
        selectedPhotosItems = []
        isProcessingPhotos = true

        Task {
            var imageData: [Data] = []
            var videoData: [Data] = []

            for item in itemsToProcess {
                // 영상인지 이미지인지 확인
                let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) })

                if let data = try? await item.loadTransferable(type: Data.self) {
                    if isVideo {
                        videoData.append(data)
                    } else {
                        imageData.append(data)
                    }
                }
            }

            // 메인 스레드에서 상태 업데이트
            await MainActor.run {
                isProcessingPhotos = false
            }

            // 영상은 각각 별도로 전송 (간격을 두고)
            for (index, video) in videoData.enumerated() {
                if index > 0 {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3초 간격
                }
                _ = await MainActor.run {
                    viewStore.send(.uploadAndSendFiles([video]))
                }
            }

            // 이미지는 한 번에 묶어서 전송
            if !imageData.isEmpty {
                _ = await MainActor.run {
                    viewStore.send(.uploadAndSendFiles(imageData))
                }
            }
        }
    }

    // 이미지 URL을 절대 경로로 변환
    private func fullImageURL(_ path: String) -> URL? {
        let fullURL: String
        if path.hasPrefix("http") {
            fullURL = path
        } else {
            fullURL = APIInfo.baseURL + path
        }
        return URL(string: fullURL)
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
    let showProfile: Bool
    let showTime: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMyMessage {
                Spacer(minLength: 60)

                HStack(alignment: .bottom, spacing: 8) {
                    // 내 메시지: 시간이 왼쪽
                    if showTime {
                        Text(DateFormatters.formatChatMessageTime(message.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .fixedSize()
                    }

                    messageContent
                }
            } else {
                // 상대방 프로필 이미지 (showProfile이 true일 때만 표시, false면 빈 공간)
                if showProfile {
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
                } else {
                    // 프로필 이미지 자리 확보 (투명 공간)
                    Color.clear
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // 닉네임 (showProfile이 true일 때만 표시)
                    if showProfile {
                        Text(message.sender.nick)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        messageContent

                        // 받은 메시지: 시간 (showTime이 true일 때만 표시)
                        if showTime {
                            Text(DateFormatters.formatChatMessageTime(message.createdAt))
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .fixedSize()
                        }
                    }
                }

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
                    .foregroundColor(isMyMessage ? .black : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMyMessage ? AppColor.disabled : Color.gray.opacity(0.2))
                    .cornerRadius(12)
            }

            // 이미지 파일
            if !message.files.isEmpty {
                imageGridView(files: message.files)
            }
        }
    }

    // 이미지 그리드 레이아웃
    @ViewBuilder
    private func imageGridView(files: [String]) -> some View {
        let count = files.count

        Group {
            switch count {
            case 1:
                // 1개: 단일 이미지
                AsyncMediaImageView(
                    imagePath: files[0],
                    width: 200,
                    height: 200
                )
                .cornerRadius(8)

            case 2:
                // 2개: 한 줄에 표시
                HStack(spacing: 2) {
                    ForEach(Array(files.enumerated()), id: \.offset) { index, filePath in
                        AsyncMediaImageView(
                            imagePath: filePath,
                            width: 98,
                            height: 98
                        )
                        .cornerRadius(6)
                    }
                }

            case 3:
                // 3개: 윗줄 2개, 아랫줄 1개 (꽉 차게)
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        AsyncMediaImageView(imagePath: files[0], width: 98, height: 98)
                            .cornerRadius(6)
                        AsyncMediaImageView(imagePath: files[1], width: 98, height: 98)
                            .cornerRadius(6)
                    }
                    AsyncMediaImageView(imagePath: files[2], width: 198, height: 98)
                        .cornerRadius(6)
                }

            case 4:
                // 4개: 2x2 그리드
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        AsyncMediaImageView(imagePath: files[0], width: 98, height: 98)
                            .cornerRadius(6)
                        AsyncMediaImageView(imagePath: files[1], width: 98, height: 98)
                            .cornerRadius(6)
                    }
                    HStack(spacing: 2) {
                        AsyncMediaImageView(imagePath: files[2], width: 98, height: 98)
                            .cornerRadius(6)
                        AsyncMediaImageView(imagePath: files[3], width: 98, height: 98)
                            .cornerRadius(6)
                    }
                }

            case 5:
                // 5개: 윗줄 2개, 아랫줄 3개
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        AsyncMediaImageView(imagePath: files[0], width: 98, height: 98)
                            .cornerRadius(6)
                        AsyncMediaImageView(imagePath: files[1], width: 98, height: 98)
                            .cornerRadius(6)
                    }
                    HStack(spacing: 2) {
                        AsyncMediaImageView(imagePath: files[2], width: 64, height: 64)
                            .cornerRadius(6)
                        AsyncMediaImageView(imagePath: files[3], width: 64, height: 64)
                            .cornerRadius(6)
                        AsyncMediaImageView(imagePath: files[4], width: 64, height: 64)
                            .cornerRadius(6)
                    }
                }

            default:
                // 그 외: 기본 처리 (1개씩 표시)
                ForEach(files, id: \.self) { filePath in
                    AsyncMediaImageView(
                        imagePath: filePath,
                        width: 200,
                        height: 200
                    )
                    .cornerRadius(8)
                }
            }
        }
    }
}
