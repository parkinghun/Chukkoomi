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
        .customNavigationTitle("CHUKKOOMI")
        .onAppear {
            store.send(.onAppear)
        }
        .modifier(HomeNavigation(store: store))
    }
    
    // MARK: - 영상 섹션
    private func videoSection() -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                if let thumbnailURL = store.videoThumbnailURL {
                    AsyncMediaImageView(
                        imagePath: thumbnailURL,
                        width: 350,
                        height: 197
                    )
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
                } else {
                    Image("mainThumbnail")
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                }
                                
                Text("Play")
                    .font(Font.appTitle)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(AppColor.pointColor)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                    .padding(16)
                    .buttonWrapper {
                        store.send(.videoThumbnailTapped)
                    }
                    .disabled(true)
            }
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.isShowingFullscreenVideo },
            set: { if !$0 { store.send(.dismissFullscreenVideo) } }
        )) {
            if let videoURL = store.videoURL {
                FullscreenVideoPlayerView(videoURL: videoURL) {
                    store.send(.dismissFullscreenVideo)
                }
            }
        }
    }
    
    // MARK: - 구단 목록 섹션
    private func teamsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TEAM")
                .font(.luckiestGuyMedium)
                .padding(.horizontal, 20)
            
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
            .filter { $0.isHomeTeam }
            .sorted { $0.minute < $1.minute }
    }
    
    // 원정팀 이벤트 (골/카드)
    private var awayTeamEvents: [MatchEvent] {
        match.events
            .filter { !$0.isHomeTeam }
            .sorted { $0.minute < $1.minute }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
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
                
                if let homeScore = match.homeScore, let awayScore = match.awayScore {
                    Text("\(homeScore) : \(awayScore)")
                        .font(.luckiestGuyLarge)
                        .foregroundColor(.primary)
                } else {
                    Text("VS")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
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
                Text(event.player.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                eventIcon
                    .frame(width: 20, height: 20)
                
                Text("\(event.minute)'")
                    .font(.caption2)
                    .foregroundColor(AppColor.divider)
            } else {
                Text("\(event.minute)'")
                    .font(.caption2)
                    .foregroundColor(AppColor.divider)
                
                eventIcon
                    .frame(width: 20, height: 20)
                
                Text(event.player.name)
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
            Image("DefaultProfile2")
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
            
        case .yellowCard:
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 14, height: 18)
                .cornerRadius(2)
            
        case .redCard:
            Rectangle()
                .fill(Color.red)
                .frame(width: 14, height: 18)
                .cornerRadius(2)
        }
    }
}

// MARK: - Fullscreen Video Player
struct FullscreenVideoPlayerView: View {
    let videoURL: String
    let onDismiss: () -> Void
    
    @State private var player: AVPlayer?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    Text("동영상을 불러올 수 없습니다")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .task {
            await loadVideo()
        }
    }
    
    private func loadVideo() async {
        isLoading = true
        
        do {
            let videoData: Data
            
            if videoURL.hasPrefix("http://") || videoURL.hasPrefix("https://") {
                guard let url = URL(string: videoURL) else {
                    isLoading = false
                    return
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                videoData = data
            } else {
                videoData = try await NetworkManager.shared.download(
                    MediaRouter.getData(path: videoURL)
                )
            }
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            try videoData.write(to: tempURL)
            
            let playerItem = AVPlayerItem(url: tempURL)
            let avPlayer = AVPlayer(playerItem: playerItem)
            
            await MainActor.run {
                self.player = avPlayer
                self.isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            print("동영상 로드 실패: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
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
