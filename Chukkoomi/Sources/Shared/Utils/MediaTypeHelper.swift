//
//  MediaTypeHelper.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import Foundation

/// 미디어 파일 타입 (이미지 vs 동영상)
enum MediaType {
    case image
    case video
    case unknown
}

enum MediaTypeHelper {

    /// 파일 경로에서 확장자를 확인하여 동영상 여부를 판단합니다
    static func isVideoPath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()
        let videoExtensions = [".mp4", ".mov", ".avi", ".m4v", ".wmv", ".flv", ".mkv"]

        return videoExtensions.contains { lowercasedPath.hasSuffix($0) }
    }

    /// 파일 경로에서 확장자를 확인하여 이미지 여부를 판단합니다
    static func isImagePath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".heif", ".bmp"]

        return imageExtensions.contains { lowercasedPath.hasSuffix($0) }
    }

    /// 파일 경로 또는 URL에서 미디어 타입 감지
    /// - Parameter path: 파일 경로 또는 URL 문자열
    /// - Returns: 감지된 미디어 타입
    static func detectMediaType(from path: String) -> MediaType {
        if isImagePath(path) {
            return .image
        } else if isVideoPath(path) {
            return .video
        } else {
            return .unknown
        }
    }
}

/// 미디어 파일 URL 생성 헬퍼
extension String {
    /// 서버 경로를 전체 URL로 변환
    /// - Returns: 전체 URL 문자열 (baseURL + /v1 + path)
    var toFullMediaURL: String {
        // 이미 전체 URL인 경우 그대로 반환
        if self.hasPrefix("http://") || self.hasPrefix("https://") {
            return self
        }

        // 경로에 /v1이 없으면 추가
        let pathWithVersion: String
        if self.hasPrefix("/v1") {
            pathWithVersion = self
        } else {
            pathWithVersion = "/v1" + self
        }

        let fullURL = APIInfo.baseURL + pathWithVersion
        print("📸 미디어 URL 생성: \(fullURL)")
        return fullURL
    }
}
