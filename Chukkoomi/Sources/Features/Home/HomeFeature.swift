//
//  HomeFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/11/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct HomeFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var teams: [FootballTeams] = FootballTeams.visibleCategories.filter { $0 != .all }
        var matches: [Match] = []
        var isShowingAllTeams: Bool = false
        var isLoading: Bool = false
        var isLoadingMatches: Bool = false

        // PostView 네비게이션
        @Presents var postList: PostFeature.State?

        // MatchInfoView 네비게이션
        @Presents var matchInfo: MatchInfoFeature.State?
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case toggleShowAllTeams
        case loadMatches
        case loadMatchesResponse(Result<[Match], Error>)
        case teamTapped(FootballTeams) // 팀 카테고리
        case matchTapped(Match) // match

        // PostView 네비게이션
        case postList(PresentationAction<PostFeature.Action>)

        // MatchInfoView 네비게이션
        case matchInfo(PresentationAction<MatchInfoFeature.Action>)

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.toggleShowAllTeams, .toggleShowAllTeams),
                 (.loadMatches, .loadMatches):
                return true
            case let (.teamTapped(lhsTeam), .teamTapped(rhsTeam)):
                return lhsTeam == rhsTeam
            case let (.matchTapped(lhsMatch), .matchTapped(rhsMatch)):
                return lhsMatch.id == rhsMatch.id
            case (.loadMatchesResponse, .loadMatchesResponse):
                return true
            case (.postList, .postList):
                return true
            case (.matchInfo, .matchInfo):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 경기 데이터 로드
                return .send(.loadMatches)

            case .loadMatches:
            // 이미 데이터가 있으면 로드하지 않음
            guard state.matches.isEmpty else {
                print("이미 경기 데이터가 로드되어 있습니다.")
                return .none
            }

            state.isLoadingMatches = true

            // ⚠️ 개발용: 더미 데이터만 사용 (API 호출 주석 처리)
            return .run { send in
                // 더미 데이터를 바로 반환
                await send(.loadMatchesResponse(.success([])))
            }

            /* 실제 API 호출 로직 (주석 처리됨)
            return .run { send in
                // 1. 먼저 캐시 확인
                if let cachedMatches = MatchCacheManager.loadMatches() {
                    await send(.loadMatchesResponse(.success(cachedMatches)))
                    return
                }

                // 2. 캐시가 없거나 만료되었으면 API 호출
                do {
                    // K리그1 (league ID: 292), 2023 시즌
                    let response = try await NetworkManager.shared.performRequest(
                        FootballRouter.fixtures(league: 292, season: 2023),
                        as: FixturesResponseDTO.self
                    )

                    let allMatches = response.toDomain

                    // 오늘 날짜(2025/11/12)와 2년 전 오늘(2023/11/12)의 월/일이 같은 경기만 필터링
                    let today = Date()
                    let calendar = Calendar.current
                    let todayMonth = calendar.component(.month, from: today)
                    let todayDay = calendar.component(.day, from: today)
                    let todayYear = calendar.component(.year, from: today)

                    let filteredMatches = allMatches.filter { match in
                        let matchMonth = calendar.component(.month, from: match.date)
                        let matchDay = calendar.component(.day, from: match.date)

                        // 같은 월/일이어야 함 (연도는 다를 수 있음 - 2년 전 데이터)
                        return matchMonth == todayMonth && matchDay == todayDay
                    }

                    // 필터링 결과 출력
                    print("=== 경기 데이터 (2년 전 오늘) ===")
                    print("현재 날짜: \(todayYear)년 \(todayMonth)월 \(todayDay)일")
                    print("전체 경기 수: \(allMatches.count)")
                    print("\(todayMonth)월 \(todayDay)일 경기: \(filteredMatches.count)개")

                    if !filteredMatches.isEmpty {
                        print("\n필터링된 경기 (2년 전 오늘):")
                        filteredMatches.forEach { match in
                            let matchYear = calendar.component(.year, from: match.date)
                            let matchMonth = calendar.component(.month, from: match.date)
                            let matchDay = calendar.component(.day, from: match.date)
                            print("\(matchYear)년 \(matchMonth)월 \(matchDay)일")
                            print("   경기 시간: \(match.date.matchDateString)")
                            print("   \(match.homeTeamName) vs \(match.awayTeamName)")
                            print("   점수: \(match.homeScore ?? 0) - \(match.awayScore ?? 0)")
                            print("---")
                        }
                    } else {
                        print("\(todayMonth)월 \(todayDay)일에 해당하는 2023 시즌 경기가 없습니다.")

                        // 샘플로 첫 5개 경기의 날짜 출력
                        if allMatches.count > 0 {
                            print("\n 전체 경기 중 첫 5개 경기 날짜:")
                            Array(allMatches.prefix(5)).forEach { match in
                                let year = calendar.component(.year, from: match.date)
                                let month = calendar.component(.month, from: match.date)
                                let day = calendar.component(.day, from: match.date)
                                print("   \(year)/\(month)/\(day) - \(match.homeTeamName) vs \(match.awayTeamName)")
                            }
                        }
                    }

                    // 3. 필터링된 데이터를 캐시에 저장
                    MatchCacheManager.saveMatches(filteredMatches)

                    await send(.loadMatchesResponse(.success(filteredMatches)))
                } catch {
                    print("API 호출 실패: \(error)")
                    await send(.loadMatchesResponse(.failure(error)))
                }
            }
            */

            case .toggleShowAllTeams:
                state.isShowingAllTeams.toggle()
                return .none

            case let .teamTapped(team):
                // PostView로 네비게이션
                print("Team tapped: \(team.rawValue)")

                // 울산은 전체 게시글을 보여줌 (teamInfo: nil)
                if team == .ulsan {
                    state.postList = PostFeature.State(teamInfo: nil)
                } else {
                    // 나머지는 해당 팀의 게시글만 필터링
                    state.postList = PostFeature.State(teamInfo: team.kLeagueTeam)
                }
                return .none

            case let .matchTapped(match):
                // MatchInfoView로 네비게이션 (경기 정보 전달)
                print("Match tapped: \(match.id)")
                state.matchInfo = MatchInfoFeature.State(match: match)
                return .none

            case let .loadMatchesResponse(.success(matches)):
                state.isLoadingMatches = false

                // 경기가 없으면 더미 데이터 사용
                if matches.isEmpty {
                    state.matches = HomeFeature.createDummyMatches()
                    print("⚠️ 오늘 경기가 없어 더미 데이터 표시: \(state.matches.count)개")
                } else {
                    state.matches = matches
                    print("경기 데이터 로드 완료: \(matches.count)개")
                }
                return .none

            case let .loadMatchesResponse(.failure(error)):
                state.isLoadingMatches = false
                print("경기 데이터 로드 실패: \(error)")
                return .none

            case .postList:
                return .none

            case .matchInfo:
                return .none
            }
        }
        .ifLet(\.$postList, action: \.postList) {
            PostFeature()
        }
        .ifLet(\.$matchInfo, action: \.matchInfo) {
            MatchInfoFeature()
        }
    }
}

// MARK: - Dummy Data
extension HomeFeature {
    /// 경기 일정이 없을 때 보여줄 더미 경기 데이터 생성
    /// - Returns: 오늘 날짜 기준 3개의 더미 경기
    static func createDummyMatches() -> [Match] {
        let today = Date()
        let calendar = Calendar.current

        let ulsanName = FootballTeams.ulsan.kLeagueTeam?.englishName ?? "Ulsan Hyundai FC"
        let jeonbukName = FootballTeams.jeonbuk.kLeagueTeam?.englishName ?? "Jeonbuk Motors"
        let pohangName = FootballTeams.pohang.kLeagueTeam?.englishName ?? "Pohang Steelers"
        let seoulName = FootballTeams.seoul.kLeagueTeam?.englishName ?? "FC Seoul"
        let jejuName = FootballTeams.jeju.kLeagueTeam?.englishName ?? "Jeju United"
        let suwonFCName = FootballTeams.suwonFC.kLeagueTeam?.englishName ?? "Suwon City FC"

        // 더미 경기 3개 생성 (이벤트 포함)
        return [
            // 경기 1: 울산 vs 전북 (3:3)
            Match(
                id: -1,
                date: calendar.date(byAdding: .hour, value: -2, to: today) ?? today,
                homeTeamName: ulsanName,
                awayTeamName: jeonbukName,
                homeScore: 3,
                awayScore: 3,
                events: [
                    MatchEvent(type: .goal, playerName: "Aubameyang", minute: 19, teamName: ulsanName),
                    MatchEvent(type: .goal, playerName: "Enzo", minute: 65, teamName: ulsanName),
                    MatchEvent(type: .yellowCard, playerName: "Silva", minute: 42, teamName: ulsanName),
                    MatchEvent(type: .goal, playerName: "Saka", minute: 25, teamName: jeonbukName),
                    MatchEvent(type: .goal, playerName: "Lewas", minute: 78, teamName: jeonbukName),
                    MatchEvent(type: .goal, playerName: "Kane", minute: 88, teamName: jeonbukName),
                    MatchEvent(type: .yellowCard, playerName: "Bruno", minute: 55, teamName: jeonbukName)
                ]
            ),
            // 경기 2: 포항 vs 서울 (2:1)
            Match(
                id: -2,
                date: calendar.date(byAdding: .hour, value: 2, to: today) ?? today,
                homeTeamName: pohangName,
                awayTeamName: seoulName,
                homeScore: 2,
                awayScore: 1,
                events: [
                    MatchEvent(type: .goal, playerName: "Son", minute: 12, teamName: pohangName),
                    MatchEvent(type: .goal, playerName: "Lee", minute: 67, teamName: pohangName),
                    MatchEvent(type: .goal, playerName: "Park", minute: 45, teamName: seoulName),
                    MatchEvent(type: .yellowCard, playerName: "Kim", minute: 30, teamName: seoulName),
                    MatchEvent(type: .redCard, playerName: "Choi", minute: 82, teamName: seoulName)
                ]
            ),
            // 경기 3: 제주 vs 수원FC (0:0)
            Match(
                id: -3,
                date: calendar.date(byAdding: .hour, value: 5, to: today) ?? today,
                homeTeamName: jejuName,
                awayTeamName: suwonFCName,
                homeScore: 0,
                awayScore: 0,
                events: [
                    MatchEvent(type: .yellowCard, playerName: "Jung", minute: 23, teamName: jejuName),
                    MatchEvent(type: .yellowCard, playerName: "Kang", minute: 67, teamName: jejuName),
                    MatchEvent(type: .yellowCard, playerName: "Hwang", minute: 51, teamName: suwonFCName)
                ]
            )
        ]
    }
}
