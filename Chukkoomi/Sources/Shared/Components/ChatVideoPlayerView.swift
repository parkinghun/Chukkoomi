//
//  ChatVideoPlayerView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/19/25.
//

import SwiftUI
import AVKit

/// 채팅용 비디오 플레이어 (자동재생 + 재생완료 후 재생 버튼 표시)
struct ChatVideoPlayerView: View {
    let mediaPath: String
    let maxWidth: CGFloat

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var hasFinishedPlaying = false
    @State private var videoDuration: Double = 0
    @State private var videoSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black

            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)  // 기본 컨트롤 숨기기
                    .onAppear {
                        setupPlayerObserver()
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                        removePlayerObserver()
                    }

                // 재생 완료 후 플레이 버튼 & 시간 표시
                if hasFinishedPlaying {
                    ZStack {
                        // 중앙에 플레이 버튼
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 48, height: 48)

                            Image(systemName: "play.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 18))
                        }
                        .onTapGesture {
                            // 다시 재생
                            hasFinishedPlaying = false
                            player.seek(to: .zero)
                            player.play()
                        }

                        // 하단에 시간 표시
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(formatDuration(videoDuration))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                // 로드 실패
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    Text("동영상을 불러올 수 없습니다")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: videoSize.width > 0 ? videoSize.width : maxWidth,
               height: videoSize.height > 0 ? videoSize.height : maxWidth)
        .task(id: mediaPath) {
            await loadVideo()
        }
    }

    // MARK: - Video Loading
    private func loadVideo() async {
        isLoading = true

        do {
            let videoData: Data

            if mediaPath.hasPrefix("http://") || mediaPath.hasPrefix("https://") {
                // 외부 URL: URLSession으로 직접 다운로드
                guard let url = URL(string: mediaPath) else {
                    isLoading = false
                    return
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                videoData = data
            } else {
                // 서버에서 다운로드
                videoData = try await NetworkManager.shared.download(
                    MediaRouter.getData(path: mediaPath)
                )
            }

            // 임시 파일로 저장 (AVPlayer는 URL이 필요)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")

            try videoData.write(to: tempURL)

            // AVPlayer 생성
            let playerItem = AVPlayerItem(url: tempURL)
            let avPlayer = AVPlayer(playerItem: playerItem)

            // 영상 정보 가져오기
            let asset = playerItem.asset
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)

            // 영상 원본 크기 가져오기
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let naturalSize = try? await track.load(.naturalSize)
                let transform = try? await track.load(.preferredTransform)

                if let size = naturalSize, size.width > 0 && size.height > 0 {
                    // preferredTransform을 확인해서 실제 표시 크기 결정
                    var actualWidth = size.width
                    var actualHeight = size.height

                    // 90도 또는 270도 회전된 경우 (세로 영상)
                    if let transform = transform, transform.a == 0 && abs(transform.b) == 1.0 {
                        swap(&actualWidth, &actualHeight)
                    }

                    // 최대 크기 제한
                    let maxHeight: CGFloat = 320
                    let minWidth: CGFloat = 150
                    let minHeight: CGFloat = 150

                    // 원본 크기에서 시작
                    var finalWidth = actualWidth
                    var finalHeight = actualHeight

                    // 가로/세로에 따라 다른 기준으로 축소
                    if actualWidth > actualHeight {
                        // 가로 영상: 너비를 기준으로
                        if finalWidth > maxWidth {
                            let ratio = maxWidth / finalWidth
                            finalWidth *= ratio
                            finalHeight *= ratio
                        }
                    } else {
                        // 세로 영상: 높이를 기준으로
                        if finalHeight > maxHeight {
                            let ratio = maxHeight / finalHeight
                            finalWidth *= ratio
                            finalHeight *= ratio
                        }
                    }

                    // 너무 작으면 확대 (비율 유지)
                    if finalWidth < minWidth && finalHeight < minHeight {
                        let widthRatio = minWidth / finalWidth
                        let heightRatio = minHeight / finalHeight
                        let ratio = min(widthRatio, heightRatio)
                        finalWidth *= ratio
                        finalHeight *= ratio
                    }

                    await MainActor.run {
                        self.player = avPlayer
                        self.videoDuration = seconds
                        self.videoSize = CGSize(width: finalWidth, height: finalHeight)
                        self.isLoading = false
                    }
                    return
                }
            }

            // 크기를 가져오지 못한 경우 기본값 사용
            await MainActor.run {
                self.player = avPlayer
                self.videoDuration = seconds
                self.videoSize = CGSize(width: maxWidth, height: maxWidth)
                self.isLoading = false
            }
        } catch is CancellationError {
            // Task가 취소되었을 때는 로그를 남기지 않음
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    // MARK: - Player Observer
    private func setupPlayerObserver() {
        guard let player = player else { return }

        // 재생 완료 알림 등록
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            hasFinishedPlaying = true
        }
    }

    private func removePlayerObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    // MARK: - Helper
    private func formatDuration(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else {
            return "0:00"
        }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
