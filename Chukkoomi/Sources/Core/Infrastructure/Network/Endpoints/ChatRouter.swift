//
//  ChatRouter.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/11/25.
//

import Foundation

// MARK: - 기능
enum ChatRouter {
    case createChatRoom(opponentId: String)  // 채팅방 생성
    case getChatRoomList                     // 채팅방 리스트 조회
    case sendMessage(roomId: String, content: String?, files: [String]?)  // 메시지 전송
    case getChatHistory(roomId: String, cursorDate: String?)  // 채팅 내역 조회 (페이지네이션)
    case uploadFiles(roomId: String, files: [MultipartFile])  // 파일 업로드
}

// MARK: - 정보
extension ChatRouter: Router {

    var version: String {
        return "v1"
    }

    var path: String {
        switch self {
        case .createChatRoom, .getChatRoomList:
            return "/\(version)/chats"
        case .sendMessage(let roomId, _, _), .getChatHistory(let roomId, _):
            return "/\(version)/chats/\(roomId)"
        case .uploadFiles(let roomId, _):
            return "/\(version)/chats/\(roomId)/files"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .createChatRoom, .sendMessage, .uploadFiles:
            return .post
        case .getChatRoomList, .getChatHistory:
            return .get
        }
    }

    var headers: [HTTPHeader]? {
        return HTTPHeader.basic
    }

    var body: AnyEncodable? {
        switch self {
        case .createChatRoom(let opponentId):
            return AnyEncodable(CreateChatRoomRequestDTO(opponentId: opponentId))
        case .sendMessage(_, let content, let files):
            return AnyEncodable(SendMessageRequestDTO(content: content, files: files))
        case .uploadFiles(_, let files):
            return AnyEncodable(UploadFilesRequestBody(files: files))
        case .getChatRoomList, .getChatHistory:
            return nil
        }
    }

    var bodyEncoder: BodyEncoder? {
        switch self {
        case .uploadFiles:
            return .multipart
        case .createChatRoom, .sendMessage:
            return .json
        case .getChatRoomList, .getChatHistory:
            return nil
        }
    }

    var query: [HTTPQuery]? {
        switch self {
        case .getChatHistory(_, let cursorDate):
            if let cursorDate = cursorDate {
                return [.custom(key: "cursor_date", value: cursorDate)]
            }
            return nil
        case .createChatRoom, .getChatRoomList, .sendMessage, .uploadFiles:
            return nil
        }
    }
}

// MARK: - Body 객체
extension ChatRouter {
    struct UploadFilesRequestBody: Encodable {
        let files: [MultipartFile]

        func encode(to encoder: Encoder) throws {
            // MultipartFormDataEncoder는 Mirror를 사용하므로 이 메서드는 호출되지 않음
        }
    }
}
