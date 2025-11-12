//
//  MediaTypeHelper.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import Foundation

enum MediaTypeHelper {

    /// 파일 경로에서 확장자를 확인하여 동영상 여부를 판단합니다
    static func isVideoPath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()
        let videoExtensions = [".mp4", ".mov", ".avi", ".m4v", ".wmv", ".flv", ".mkv"]

        return videoExtensions.contains { lowercasedPath.hasSuffix($0) }
    }
}
