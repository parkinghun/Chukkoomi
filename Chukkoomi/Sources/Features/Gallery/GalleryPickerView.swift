//
//  GalleryPickerView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/10/25.
//

import SwiftUI
import ComposableArchitecture
import Photos
import AVKit

struct GalleryPickerView: View {
    let store: StoreOf<GalleryPickerFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 선택된 이미지 미리보기
                selectedImagePreview(viewStore: viewStore)

                // 최근 항목 텍스트
                HStack {
                    Text("최근 항목")
                        .font(.appBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                    Spacer()
                }
                .padding(.horizontal, AppPadding.large)
                .padding(.vertical, AppPadding.medium)
                .background(Color(uiColor: .systemBackground))

                // 미디어 그리드
                if viewStore.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    mediaGrid(viewStore: viewStore)
                        .padding(.horizontal, 4)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(viewStore.pickerMode == .profileImage ? "사진 선택" : "미디어 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewStore.send(.cancel)
                    } label: {
                        AppIcon.xmark
                            .foregroundStyle(.black)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewStore.send(.confirmSelection)
                    } label: {
                        Text(viewStore.pickerMode.buttonTitle)
                            .foregroundStyle(viewStore.selectedItem != nil ? .black : .gray)
                    }
                    .disabled(viewStore.selectedItem == nil)
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            // 네비게이션 연결
            .modifier(GalleryPickerNavigation(store: store))
        }
    }

    // MARK: - 선택된 이미지 미리보기
    private func selectedImagePreview(viewStore: ViewStoreOf<GalleryPickerFeature>) -> some View {
        Group {
            if viewStore.pickerMode == .profileImage {
                // 프로필 이미지 모드: 원형 크롭 미리보기
                if let image = viewStore.selectedImage {
                    GeometryReader { geometry in
                        ZStack {
                            // 전체 이미지
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()

                            // 어두운 오버레이 (원형 부분만 잘라냄)
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .mask {
                                    ZStack {
                                        Rectangle()
                                            .fill(Color.white)
                                        Circle()
                                            .fill(Color.black)
                                            .frame(width: 300, height: 300)
                                            .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                                }

                            // 원형 테두리
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 300, height: 300)
                        }
                    }
                    .frame(height: 300)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 300)
                        .overlay {
                            VStack(spacing: AppPadding.medium) {
                                AppIcon.photo
                                    .font(.system(size: 50))
                                    .foregroundStyle(.gray)
                                Text("선택된 사진이 없습니다")
                                    .font(.appBody)
                                    .foregroundStyle(.gray)
                            }
                        }
                }
            } else {
                // 게시물 모드 (16:9 비율)
                Color.clear
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        GeometryReader { geometry in
                            let width = geometry.size.width
                            let height = geometry.size.height

                            if let selectedItem = viewStore.selectedItem {
                                if selectedItem.mediaType == .video {
                                    // 비디오 재생
                                    AssetVideoPlayerView(asset: selectedItem.asset)
                                        .frame(width: width, height: height)
                                        .id(selectedItem.id)  // asset이 바뀌면 뷰를 새로 생성
                                } else if let image = viewStore.selectedImage {
                                    // 이미지 표시
                                    ZStack {
                                        Color.black
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: width, height: height)
                                            .clipped()
                                    }
                                    .frame(width: width, height: height)
                                }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: width, height: height)
                                    .overlay {
                                        VStack(spacing: AppPadding.medium) {
                                            AppIcon.photo
                                                .font(.system(size: 50))
                                                .foregroundStyle(.gray)
                                            Text("선택된 미디어가 없습니다")
                                                .font(.appBody)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                            }
                        }
                    }
            }
        }
    }

    // MARK: - 미디어 그리드
    private func mediaGrid(viewStore: ViewStoreOf<GalleryPickerFeature>) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(viewStore.mediaItems) { item in
                    mediaGridItem(item: item, viewStore: viewStore)
                }
            }
        }
    }

    // MARK: - 미디어 그리드 아이템
    private func mediaGridItem(item: GalleryPickerFeature.MediaItem, viewStore: ViewStoreOf<GalleryPickerFeature>) -> some View {
        GeometryReader { geometry in
            AssetImageView(asset: item.asset, size: geometry.size)
                .frame(width: geometry.size.width, height: geometry.size.width)
                .clipped()
                .overlay(
                    Group {
                        // 비디오 표시
                        if item.mediaType == .video, let duration = item.duration {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text(formatDuration(duration))
                                        .font(.appCaption)
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(4)
                                }
                            }
                        }
                    }
                )
                .overlay(
                    // 선택 표시
                    Group {
                        if viewStore.selectedItem?.id == item.id {
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.blue, lineWidth: 3)
                        }
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    viewStore.send(.mediaItemSelected(item))
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Helper
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AssetImageView
struct AssetImageView: View {
    let asset: PHAsset
    let size: CGSize
    @State private var image: UIImage?
    @Environment(\.displayScale) var displayScale

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size.width, height: size.height)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(
            width: size.width * displayScale,
            height: size.height * displayScale
        )

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { loadedImage, _ in
            self.image = loadedImage
        }
    }
}

// MARK: - AssetVideoPlayerView
struct AssetVideoPlayerView: View {
    let asset: PHAsset
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            Color.black

            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func loadVideo() {
        // 상태 초기화
        isLoading = true

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let id = PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { [assetID = asset.localIdentifier] playerItem, _ in
            DispatchQueue.main.async {
                // 현재 asset과 동일한지 확인 (다른 비디오로 전환되지 않았는지)
                guard assetID == self.asset.localIdentifier else { return }

                if let playerItem = playerItem {
                    self.player = AVPlayer(playerItem: playerItem)
                    self.isLoading = false
                }
            }
        }
        requestID = id
    }

    private func cleanup() {
        // 진행 중인 요청 취소
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
            self.requestID = nil
        }

        // 플레이어 정리
        player?.pause()
        player = nil
        isLoading = true
    }
}

// MARK: - Navigation 구성
private struct GalleryPickerNavigation: ViewModifier {
    let store: StoreOf<GalleryPickerFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(
                store: store.scope(state: \.$editVideo, action: \.editVideo)
            ) { store in
                EditVideoView(store: store)
            }
            .navigationDestination(
                store: store.scope(state: \.$editPhoto, action: \.editPhoto)
            ) { _ in
                Text("EditPhotoView 구현 필요")
            }
    }
}
