//
//  HomeView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/5/25.
//

import SwiftUI
import ComposableArchitecture
import AVKit

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 영상 섹션 (lightGray 배경 영역)
                VStack(spacing: 0) {
                    videoSection()
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
                .background(Color(uiColor: .systemGray6))

                VStack(alignment: .leading, spacing: 24) {
                    teamsSection()
                        .padding(.top, 24)

                    matchScheduleSection()
                }
                .padding(.bottom, 40)
                .background(Color.white)
                .clipShape(
                    .rect(
                        topLeadingRadius: 30,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 24
                    )
                )
            }
        }
        .background(Color(uiColor: .systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("CHUKKOOMI")
                    .font(.luckiestGuyLarge)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        // 네비게이션 연결
        .modifier(HomeNavigation(store: store))
    }

    // MARK: - 영상 섹션
    private func videoSection() -> some View {
        VStack(spacing: 0) {
            // 영상 플레이어 (16:9 비율)
            Color.black
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    // TODO: 실제 영상 URL을 받아서 VideoPlayer 구현
                    VStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                        Text("영상 플레이어")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 8)
                    }
                }
                .cornerRadius(20)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - 구단 목록 섹션
    private func teamsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TEAM")
                .font(.luckiestGuyMedium)
//                .font(.title2)
//                .fontWeight(.bold)
                .padding(.horizontal, 20)

            // 가로 스크롤
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(store.teams, id: \.self) { team in
                        TeamLogoButton(team: team, onTap: {
                            store.send(.teamTapped(team))
                        })
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - 경기 일정 섹션
    private func matchScheduleSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TODAY'S")
                .font(.luckiestGuyMedium)
                .padding(.horizontal, 20)

            if store.isLoadingMatches {
                ProgressView("경기 일정을 불러오는 중...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if store.matches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(AppColor.divider)
                    Text("오늘은 경기가 없습니다")
                        .font(.body)
                        .foregroundColor(AppColor.divider)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // 모든 경기 표시 (스크롤 가능)
                VStack(spacing: 16) {
                    ForEach(store.matches) { match in
                        Button {
                            store.send(.matchTapped(match))
                        } label: {
                            MatchCard(match: match)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 구단 로고 버튼
struct TeamLogoButton: View {
    let team: FootballTeams
    let onTap: () -> Void

    var body: some View {
        Image(team.logoImageName)
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(AppColor.divider, lineWidth: 1)
            )
            .buttonWrapper(action: onTap)
    }
}

// MARK: - Navigation 구성
private struct HomeNavigation: ViewModifier {
    let store: StoreOf<HomeFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(
                store: store.scope(state: \.$postList, action: \.postList)
            ) { store in
                PostView(store: store)
            }
            .navigationDestination(
                store: store.scope(state: \.$matchInfo, action: \.matchInfo)
            ) { store in
                MatchInfoView(store: store)
            }
    }
}

// MARK: - 경기 카드
struct MatchCard: View {
    let match: Match

    // 홈팀, 원정팀 로컬 데이터 찾기
    private var homeTeam: KLeagueTeam? {
        KLeagueTeam.find(by: match.homeTeamName)
    }

    private var awayTeam: KLeagueTeam? {
        KLeagueTeam.find(by: match.awayTeamName)
    }

    // 홈팀 이벤트 (골/카드)
    private var homeTeamEvents: [MatchEvent] {
        match.events
            .filter { $0.teamName == match.homeTeamName }
            .sorted { $0.minute < $1.minute }
    }

    // 원정팀 이벤트 (골/카드)
    private var awayTeamEvents: [MatchEvent] {
        match.events
            .filter { $0.teamName == match.awayTeamName }
            .sorted { $0.minute < $1.minute }
    }

    var body: some View {
        VStack(spacing: 12) {
            // 경기 정보
            HStack(spacing: 20) {
                // 홈 팀
                VStack(spacing: 8) {
                    if let homeTeam = homeTeam {
                        Image(homeTeam.logoImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                    } else {
                        Circle()
                            .fill(AppColor.divider.opacity(0.2))
                            .frame(width: 50, height: 50)
                    }

                    Text(homeTeam?.koreanName ?? match.homeTeamName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)

                // 스코어
                if let homeScore = match.homeScore, let awayScore = match.awayScore {
                    Text("\(homeScore) : \(awayScore)")
                        .font(.luckiestGuyLarge)
                        .foregroundColor(.primary)
                } else {
                    Text("VS")
                        .font(.headline)
                        .foregroundColor(.gray)
                }

                // 원정 팀
                VStack(spacing: 8) {
                    if let awayTeam = awayTeam {
                        Image(awayTeam.logoImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                    } else {
                        Circle()
                            .fill(AppColor.divider.opacity(0.2))
                            .frame(width: 50, height: 50)
                    }

                    Text(awayTeam?.koreanName ?? match.awayTeamName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }

            // 경기 이벤트 표시
            if !match.events.isEmpty {
                Divider()
                    .padding(.vertical, 8)

                HStack(alignment: .top, spacing: 16) {
                    // 홈팀 이벤트 (가운데로 몰리게 - trailing 정렬)
                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(homeTeamEvents) { event in
                            EventRow(event: event, isHomeTeam: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    // 원정팀 이벤트 (가운데로 몰리게 - leading 정렬)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(awayTeamEvents) { event in
                            EventRow(event: event, isHomeTeam: false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: .systemGray5), lineWidth: 1)
        )
    }
}

// MARK: - 이벤트 행
struct EventRow: View {
    let event: MatchEvent
    let isHomeTeam: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isHomeTeam {
                // 홈팀: 이름 - 아이콘 - 시간 (trailing 정렬)
                Text(event.playerName)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                eventIcon
                    .frame(width: 20, height: 20)

                Text("\(event.minute)'")
                    .font(.caption2)
                    .foregroundColor(AppColor.divider)
            } else {
                // 원정팀: 시간 - 아이콘 - 이름 (leading 정렬)
                Text("\(event.minute)'")
                    .font(.caption2)
                    .foregroundColor(AppColor.divider)

                eventIcon
                    .frame(width: 20, height: 20)

                Text(event.playerName)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var eventIcon: some View {
        switch event.type {
        case .goal:
            // 골 아이콘 - "기본 프로필2" 이미지 사용
            Image("기본 프로필2")
                .resizable()
                .scaledToFit()
                .clipShape(Circle())

        case .yellowCard:
            // 옐로우 카드 - 나중에 이미지로 대체 예정
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 14, height: 18)
                .cornerRadius(2)

        case .redCard:
            // 레드 카드 - 나중에 이미지로 대체 예정
            Rectangle()
                .fill(Color.red)
                .frame(width: 14, height: 18)
                .cornerRadius(2)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(
            store: Store(
                initialState: HomeFeature.State()
            ) {
                HomeFeature()
            }
        )
    }
}
