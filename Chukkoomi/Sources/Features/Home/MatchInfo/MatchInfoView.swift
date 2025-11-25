//
//  MatchInfoView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/24/25.
//

import SwiftUI
import ComposableArchitecture

struct MatchInfoView: View {
    let store: StoreOf<MatchInfoFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 스코어
                ScoreView(match: store.match)

                // 홈/원정 탭
                TeamTabView(store: store)
                    .padding(.top, AppPadding.medium)

                // 라인업
                LineupView(matchDetail: store.matchDetail, selectedTeam: store.selectedTeam)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("경기 정보")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - 스코어 뷰
private struct ScoreView: View {
    let match: Match

    // 홈팀, 원정팀 로컬 데이터 찾기
    private var homeTeam: KLeagueTeam? {
        KLeagueTeam.find(by: match.homeTeamName)
    }

    private var awayTeam: KLeagueTeam? {
        KLeagueTeam.find(by: match.awayTeamName)
    }

    var body: some View {
        ZStack {
            // 배경 이미지
            Image("MatchBackground")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipped()

            // 경기 정보
            VStack(spacing: AppPadding.large) {
                Spacer()

                HStack(spacing: AppPadding.large) {
                    // 홈 팀
                    VStack(spacing: AppPadding.small) {
                        if let homeTeam = homeTeam {
                            Image(homeTeam.logoImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 60, height: 60)
                        }

                        Text(homeTeam?.koreanName ?? match.homeTeamName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(width: 80)

                    // 스코어
                    if let homeScore = match.homeScore, let awayScore = match.awayScore {
                        Text("\(homeScore) : \(awayScore)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("VS")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    // 원정 팀
                    VStack(spacing: AppPadding.small) {
                        if let awayTeam = awayTeam {
                            ZStack {
                                // 흰색 배경 (이미지 형태로 마스킹)
                                Color.white
                                    .mask(
                                        Image(awayTeam.logoImageName)
                                            .resizable()
                                            .scaledToFit()
                                    )
                                    .frame(width: 60, height: 60)

                                // 실제 이미지
                                Image(awayTeam.logoImageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                            }
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 60, height: 60)
                        }

                        Text(awayTeam?.koreanName ?? match.awayTeamName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(width: 80)
                }

                // 날짜 정보
                Text(match.date.matchDateString)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 28)
            }
        }
        .frame(height: 300)
    }
}

// MARK: - 홈/원정 탭
private struct TeamTabView: View {
    let store: StoreOf<MatchInfoFeature>

    // 홈팀, 원정팀 로컬 데이터 찾기
    private var homeTeam: KLeagueTeam? {
        KLeagueTeam.find(by: store.match.homeTeamName)
    }

    private var awayTeam: KLeagueTeam? {
        KLeagueTeam.find(by: store.match.awayTeamName)
    }

    var body: some View {
        HStack(spacing: 0) {
            // 홈팀 탭
            TeamTabButton(
                store: store,
                teamType: .home,
                title: homeTeam?.koreanName ?? store.match.homeTeamName
            )

            // 원정팀 탭
            TeamTabButton(
                store: store,
                teamType: .away,
                title: awayTeam?.koreanName ?? store.match.awayTeamName
            )
        }
        .frame(height: 50)
        .padding(.horizontal, AppPadding.large)
        .background(.white)
        .padding(.horizontal, AppPadding.large)
    }
}

// MARK: - 팀 탭 버튼
private struct TeamTabButton: View {
    let store: StoreOf<MatchInfoFeature>
    let teamType: MatchInfoFeature.State.TeamType
    let title: String

    var body: some View {
        Button {
            store.send(.selectTeam(teamType))
        } label: {
            VStack(spacing: 0) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(store.selectedTeam == teamType ? .black : .gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                // 선택된 탭 표시
                if store.selectedTeam == teamType {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 3)
                } else {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 라인업
private struct LineupView: View {
    let matchDetail: MatchDetail?
    let selectedTeam: MatchInfoFeature.State.TeamType

    @State private var homeUniformData: Data?
    @State private var awayUniformData: Data?
    @State private var isLoadingHomeUniform: Bool = true
    @State private var isLoadingAwayUniform: Bool = true

    var body: some View {
        ZStack {
            Image("SoccerField")
                .resizable()
                .frame(maxHeight: .infinity)
                .rotationEffect(.degrees(selectedTeam == .away ? 180 : 0))

            if let matchDetail {
                if selectedTeam == .home {
                    if isLoadingHomeUniform {
                        VStack {
                            GoalkeeperRowView(
                                player: matchDetail.homeKeeper,
                                uniformImagePath: matchDetail.homeUniform,
                                onImageLoaded: { data in
                                    homeUniformData = data
                                    isLoadingHomeUniform = false
                                }
                            )
                            .hidden()

                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
                    } else {
                        VStack(spacing: 0) {
                            Spacer()

                            GoalkeeperRowView(
                                player: matchDetail.homeKeeper,
                                uniformImagePath: matchDetail.homeUniform,
                                onImageLoaded: { data in
                                    homeUniformData = data
                                }
                            )

                            if let uniformData = homeUniformData {
                                Spacer()
                                FieldPlayerRowView(players: Array(matchDetail.homeDefends.reversed()), uniformImageData: uniformData)
                                Spacer()
                                FieldPlayerRowView(players: Array(matchDetail.homeMidFields.reversed()), uniformImageData: uniformData)
                                Spacer()
                                FieldPlayerRowView(players: Array(matchDetail.homeForwards.reversed()), uniformImageData: uniformData)
                            }

                            Spacer()
                        }
                        .padding(.vertical, AppPadding.large)
                    }
                } else {
                    if isLoadingAwayUniform {
                        VStack {
                            GoalkeeperRowView(
                                player: matchDetail.awayKeeper,
                                uniformImagePath: matchDetail.awayUniform,
                                onImageLoaded: { data in
                                    awayUniformData = data
                                    isLoadingAwayUniform = false
                                }
                            )
                            .hidden()

                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
                    } else {
                        VStack(spacing: 0) {
                            Spacer()

                            if let uniformData = awayUniformData {
                                FieldPlayerRowView(players: matchDetail.awayForwards, uniformImageData: uniformData)
                                Spacer()
                                FieldPlayerRowView(players: matchDetail.awayMidFields, uniformImageData: uniformData)
                                Spacer()
                                FieldPlayerRowView(players: matchDetail.awayDefends, uniformImageData: uniformData)
                                Spacer()
                            }

                            GoalkeeperRowView(
                                player: matchDetail.awayKeeper,
                                uniformImagePath: matchDetail.awayUniform,
                                onImageLoaded: { data in
                                    awayUniformData = data
                                }
                            )

                            Spacer()
                        }
                        .padding(.vertical, AppPadding.large)
                    }
                }
            }
        }
        .frame(height: 460)
    }
}

// MARK: - 골키퍼 행 뷰
// 한번만 이미지 받아오기 위해 골키퍼 뷰를 구분
private struct GoalkeeperRowView: View {
    let player: Player
    let uniformImagePath: String
    let onImageLoaded: (Data) -> Void

    var body: some View {
        GoalkeeperPlayerView(
            player: player,
            uniformImagePath: uniformImagePath,
            onImageLoaded: onImageLoaded
        )
    }
}

// MARK: - 필드 선수 행 뷰
private struct FieldPlayerRowView: View {
    let players: [Player]
    let uniformImageData: Data

    var body: some View {
        HStack(spacing: 0) {
            ForEach(players.indices, id: \.self) { index in
                if index == 0 {
                    Spacer()
                }

                FieldPlayerView(player: players[index], uniformImageData: uniformImageData)

                Spacer()
            }
        }
        .padding(.horizontal, AppPadding.large)
    }
}

// MARK: - 골키퍼 선수 뷰
private struct GoalkeeperPlayerView: View {
    let player: Player
    let uniformImagePath: String
    let onImageLoaded: (Data) -> Void

    var body: some View {
        VStack(spacing: 4) {
            AsyncMediaImageView(
                imagePath: uniformImagePath,
                width: 40,
                height: 40,
                onImageLoaded: onImageLoaded
            )
            .clipShape(Circle())

            PlayerInfoView(player: player)
        }
    }
}

// MARK: - 필드 선수 뷰
private struct FieldPlayerView: View {
    let player: Player
    let uniformImageData: Data

    var body: some View {
        VStack(spacing: 4) {
            if let uiImage = UIImage(data: uniformImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }

            PlayerInfoView(player: player)
        }
    }
}

// MARK: - 선수 정보 뷰
private struct PlayerInfoView: View {
    let player: Player

    var body: some View {
        HStack(spacing: 2) {
            Text("\(player.number)")
                .font(.appCaption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 0)

            Text(player.name)
                .font(.appCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 0)
        }
        .frame(width: 72)
    }
}
