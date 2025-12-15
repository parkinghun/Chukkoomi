//
//  NetworkError.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import Foundation

// MARK: - NetworkError
enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case statusCode(Int, message: String?) // 서버 에러 메시지 추가
    case noData
    case decodingFailed(Error)
    case unauthorized // 토큰 갱신 실패
    case refreshTokenExpired // RefreshToken 만료

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "유효하지 않은 응답입니다."
        case .statusCode(let code, let message):
            if let message = message {
                return message // 서버 메시지 우선 사용
            }
            return "HTTP 상태 코드 에러: \(code)"
        case .noData:
            return "데이터가 없습니다."
        case .decodingFailed(let error):
            return "디코딩에 실패했습니다: \(error.localizedDescription)"
        case .unauthorized:
            return "인증에 실패했습니다. 다시 로그인해주세요."
        case .refreshTokenExpired:
            return "로그인 세션이 만료되었습니다. 다시 로그인해주세요."
        }
    }
}
