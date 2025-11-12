//
//  KLeagueTeam.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import Foundation

/// K리그 1부 리그 팀 정보
struct KLeagueTeam: Identifiable, Equatable {
    let id: String
    let koreanName: String
    let englishName: String
    let logoImageName: String  // Assets에 저장된 로고 이미지 이름

    /// 영어 팀 이름으로 K리그 팀 찾기
    /// - Parameter englishName: API에서 받아온 영어 팀 이름
    /// - Returns: 매칭되는 K리그 팀 (없으면 nil)
    static func find(by englishName: String) -> KLeagueTeam? {
        // 정확히 매칭되는 경우
        if let team = allTeams.first(where: { $0.englishName == englishName }) {
            return team
        }

        // 부분 매칭 (예: "Ulsan HD FC" → "Ulsan HD")
        return allTeams.first { team in
            englishName.contains(team.englishName) || team.englishName.contains(englishName)
        }
    }
}

extension KLeagueTeam {

    /// K리그 1부 리그 전체 팀 목록
    static let allTeams: [KLeagueTeam] = [
        KLeagueTeam(
            id: "1",
            koreanName: "울산 HD FC",
            englishName: "Ulsan Hyundai FC",
            logoImageName: "team_ulsan"
        ),
        KLeagueTeam(
            id: "2",
            koreanName: "전북 현대 모터스",
            englishName: "Jeonbuk Motors",
            logoImageName: "team_jeonbuk"
        ),
        KLeagueTeam(
            id: "3",
            koreanName: "포항 스틸러스",
            englishName: "Pohang Steelers",
            logoImageName: "team_pohang"
        ),
        KLeagueTeam(
            id: "4",
            koreanName: "수원 FC",
            englishName: "Suwon City FC",
            logoImageName: "team_suwon_fc"
        ),
        KLeagueTeam( // 1
            id: "5",
            koreanName: "김천상무 FC",
            englishName: "Suwon Bluewings",
            logoImageName: "team_kimcheon"
        ),
        KLeagueTeam(
            id: "6",
            koreanName: "강원 FC",
            englishName: "Gangwon FC",
            logoImageName: "team_gangwon"
        ),
        KLeagueTeam(
            id: "7",
            koreanName: "제주 유나이티드",
            englishName: "Jeju United",
            logoImageName: "team_jeju"
        ),
        KLeagueTeam(
            id: "8",
            koreanName: "FC 안양",
            englishName: "Incheon United",
            logoImageName: "team_anyang"
        ),
        KLeagueTeam(
            id: "9",
            koreanName: "FC 서울",
            englishName: "FC Seoul",
            logoImageName: "team_seoul"
        ),
        KLeagueTeam(
            id: "10",
            koreanName: "광주 FC",
            englishName: "Gwangju FC",
            logoImageName: "team_gwangju"
        ),
        KLeagueTeam(
            id: "11",
            koreanName: "대전 하나 시티즌",
            englishName: "Daejeon Citizen",
            logoImageName: "team_daejeon"
        ),
        KLeagueTeam(
            id: "12",
            koreanName: "대구 FC",
            englishName: "Daegu FC",
            logoImageName: "team_daegu"
        )
    ]
}
