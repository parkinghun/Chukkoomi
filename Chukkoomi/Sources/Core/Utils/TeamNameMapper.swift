//
//  TeamNameMapper.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/11/25.
//

import Foundation

/// K리그 팀 이름 한글 매핑
enum TeamNameMapper {

    // 팀 이름 매핑 딕셔너리
    private static let teamNames: [String: String] = [
        // K리그1
        "Ulsan Hyundai FC": "울산 HD FC",
        "Jeonbuk Motors": "전북 현대 모터스",
        "Pohang Steelers": "포항 스틸러스",
        "Daegu FC": "대구 FC",
        "Suwon Bluewings": "수원 삼성 블루윙즈",
        "Suwon City FC": "수원 FC",
        "Gangwon FC": "강원 FC",
        "Jeju United": "제주 유나이티드",
        "Incheon United": "인천 유나이티드",
        "FC Seoul": "FC 서울",
        "Gwangju FC": "광주 FC",
        "Daejeon Citizen": "대전 하나 시티즌",
    ]

    /// 영어 팀 이름을 한글로 변환
    /// - Parameter englishName: 영어 팀 이름
    /// - Returns: 한글 팀 이름 (매핑되지 않으면 원본 반환)
    static func toKorean(_ englishName: String) -> String {
        // 정확히 매칭되는 경우
        if let koreanName = teamNames[englishName] {
            return koreanName
        }

        // 부분 매칭 (예: "Ulsan HD FC" → "울산 HD")
        for (english, korean) in teamNames {
            if englishName.contains(english) {
                return korean
            }
        }

        return englishName
    }
}
