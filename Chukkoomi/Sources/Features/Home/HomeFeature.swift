//
//  HomeFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/11/25.
//

import ComposableArchitecture
import SwiftUI

struct HomeFeature: Reducer {

    // MARK: - State
    struct State: Equatable {
        var teams: [KLeagueTeam] = KLeagueTeam.allTeams
        var matches: [Match] = []
        var isShowingAllTeams: Bool = false
        var isLoading: Bool = false
        var isLoadingMatches: Bool = false
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case toggleShowAllTeams
        case loadMatches
        case loadMatchesResponse(Result<[Match], Error>)
        case teamTapped(String) // team ID

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.toggleShowAllTeams, .toggleShowAllTeams),
                 (.loadMatches, .loadMatches):
                return true
            case let (.teamTapped(lhsId), .teamTapped(rhsId)):
                return lhsId == rhsId
            case (.loadMatchesResponse, .loadMatchesResponse):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Reducer
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
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

        case .toggleShowAllTeams:
            state.isShowingAllTeams.toggle()
            return .none

        case let .teamTapped(teamId):
            // TODO: 구단 상세 화면으로 이동
            print("Team tapped: \(teamId)")
            return .none

        case let .loadMatchesResponse(.success(matches)):
            state.isLoadingMatches = false
            state.matches = matches
            print("경기 데이터 로드 완료: \(matches.count)개")
            return .none

        case let .loadMatchesResponse(.failure(error)):
            state.isLoadingMatches = false
            print("경기 데이터 로드 실패: \(error)")
            return .none
        }
    }
}
