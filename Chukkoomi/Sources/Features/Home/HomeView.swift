//
//  HomeView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/5/25.
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                cheeringSection()

                matchScheduleSection()

                teamsSection()
            }
            .padding(.top, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                    Image("Chukkoomi")
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: 158, height: 28)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        // 네비게이션 연결
        .modifier(HomeNavigation(store: store))
    }
    
    // MARK: - 응원 섹션
    private func cheeringSection() -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ooo님 우리팀")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("응원하러 가볼까요?")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Spacer()

            // 대체 이미지 (축구공 캐릭터)
            Image(systemName: "figure.soccer")
                .font(.system(size: 80))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: - 경기 일정 섹션
    private func matchScheduleSection() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("오늘 경기 일정")
                .font(.title2)
                .fontWeight(.bold)
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
                TabView {
                    ForEach(store.matches) { match in
                        MatchCard(match: match)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 180)
            }
        }
    }

    // MARK: - 구단 목록 섹션
    private func teamsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("구단 목록")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text(store.isShowingAllTeams ? "접기" : "더보기")
                    .font(.subheadline)
                    .foregroundColor(AppColor.divider)
                    .buttonWrapper {
                        store.send(.toggleShowAllTeams)
                    }
            }
            .padding(.horizontal, 20)

            let columns = [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ]

            let displayedTeams = store.isShowingAllTeams
                ? store.teams
                : Array(store.teams.prefix(4))

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(displayedTeams) { team in
                    TeamLogoButton(team: team, onTap: {
                        store.send(.teamTapped(team.id))
                    })
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 구단 로고 버튼
struct TeamLogoButton: View {
    let team: KLeagueTeam
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

    var body: some View {
        VStack(spacing: 16) {
            // 경기 날짜/시간 (수평 센터)
            Text(match.date.matchDateString)
                .font(.subheadline)
                .foregroundColor(AppColor.divider)
                .frame(maxWidth: .infinity, alignment: .center)

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
                        .font(.title2)
                        .fontWeight(.bold)
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
        }
        .padding(16)
        .cornerRadius(12)
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
