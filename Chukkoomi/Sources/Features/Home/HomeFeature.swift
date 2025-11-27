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
        
        // 비디오 관련
        var videoThumbnailURL: String? = nil // 나중에 서버에서 받을 썸네일 URL
        var videoURL: String? = nil // 나중에 서버에서 받을 비디오 URL
        var isShowingFullscreenVideo: Bool = false
        
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
        
        // 비디오 관련
        case videoThumbnailTapped
        case dismissFullscreenVideo
        
        // PostView 네비게이션
        case postList(PresentationAction<PostFeature.Action>)
        
        // MatchInfoView 네비게이션
        case matchInfo(PresentationAction<MatchInfoFeature.Action>)
        
        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                (.toggleShowAllTeams, .toggleShowAllTeams),
                (.loadMatches, .loadMatches),
                (.videoThumbnailTapped, .videoThumbnailTapped),
                (.dismissFullscreenVideo, .dismissFullscreenVideo):
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
                
                return .run { send in
                    do {
                        let response = try await NetworkManager.shared.performRequest(
                            MatchRouter.fetchRecentMatches,
                            as: MatchDetailListDTO.self
                        )
                        
                        let matches = response.toMatches
                        print("경기 데이터 로드 완료: \(matches.count)개")
                        await send(.loadMatchesResponse(.success(matches)))
                    } catch {
                        print("경기 데이터 로드 실패: \(error)")
                        await send(.loadMatchesResponse(.failure(error)))
                    }
                }
                
            case .toggleShowAllTeams:
                state.isShowingAllTeams.toggle()
                return .none
                
            case let .teamTapped(team):
                // PostView로 네비게이션
                print("Team tapped: \(team.rawValue)")
                
                state.postList = PostFeature.State(teamInfo: team.kLeagueTeam)
                return .none
                
            case let .matchTapped(match):
                // MatchInfoView로 네비게이션 (경기 정보 전달)
                print("Match tapped: \(match.id)")
                state.matchInfo = MatchInfoFeature.State(match: match)
                return .none
                
            case let .loadMatchesResponse(.success(matches)):
                state.isLoadingMatches = false
                state.matches = matches
                
                if matches.isEmpty {
                    print("경기 데이터가 없습니다.")
                } else {
                    print("경기 데이터 로드 완료: \(matches.count)개")
                }
                return .none
                
            case let .loadMatchesResponse(.failure(error)):
                state.isLoadingMatches = false
                print("경기 데이터 로드 실패: \(error)")
                return .none
                
            case .videoThumbnailTapped:
                state.isShowingFullscreenVideo = true
                return .none
                
            case .dismissFullscreenVideo:
                state.isShowingFullscreenVideo = false
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
                    MatchEvent(type: .goal, player: Player(id: UUID().uuidString, number: 9, name: "Aubameyang"), minute: 19, isHomeTeam: true),
                    MatchEvent(type: .goal, player: Player(id: UUID().uuidString, number: 8, name: "Enzo"), minute: 65, isHomeTeam: true),
                    MatchEvent(type: .yellowCard, player: Player(id: UUID().uuidString, number: 7, name: "Silva"), minute: 42, isHomeTeam: true),
                    MatchEvent(type: .goal, player: Player(id: UUID().uuidString, number: 11, name: "Saka"), minute: 25, isHomeTeam: false),
                    MatchEvent(type: .goal, player: Player(id: UUID().uuidString, number: 9, name: "Lewas"), minute: 78, isHomeTeam: false),
                    MatchEvent(type: .goal, player: Player(id: UUID().uuidString, number: 10, name: "Kane"), minute: 88, isHomeTeam: false),
                    MatchEvent(type: .yellowCard, player: Player(id: UUID().uuidString, number: 8, name: "Bruno"), minute: 55, isHomeTeam: false)
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
                    MatchEvent(type: .goal, player: Player(id: UUID().uuidString, number: 7, name: "Son"), minute: 12, isHomeTeam: true),
                    MatchEvent(type: .goal, player: Player(id: UUID().uuidString, number: 10, name: "Lee"), minute: 67, isHomeTeam: true),
                    MatchEvent(type: .goal, player: Player(id: UUID().uuidString, number: 9, name: "Park"), minute: 45, isHomeTeam: false),
                    MatchEvent(type: .yellowCard, player: Player(id: UUID().uuidString, number: 5, name: "Kim"), minute: 30, isHomeTeam: false),
                    MatchEvent(type: .redCard, player: Player(id: UUID().uuidString, number: 4, name: "Choi"), minute: 82, isHomeTeam: false)
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
                    MatchEvent(type: .yellowCard, player: Player(id: UUID().uuidString, number: 6, name: "Jung"), minute: 23, isHomeTeam: true),
                    MatchEvent(type: .yellowCard, player: Player(id: UUID().uuidString, number: 8, name: "Kang"), minute: 67, isHomeTeam: true),
                    MatchEvent(type: .yellowCard, player: Player(id: UUID().uuidString, number: 3, name: "Hwang"), minute: 51, isHomeTeam: false)
                ]
            )
        ]
    }
}
