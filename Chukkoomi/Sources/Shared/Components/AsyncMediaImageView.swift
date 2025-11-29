//
//  AsyncMediaImageView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import SwiftUI

// MARK: - 간단한 메모리 캐시
private actor ImageCache {
    static let shared = ImageCache()
    private var cache: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        return cache[key]
    }

    func set(_ key: String, data: Data) {
        cache[key] = data
    }
}

/// 미디어 경로를 받아 비동기로 다운로드하고 표시하는 뷰
struct AsyncMediaImageView: View {
    let imagePath: String
    let width: CGFloat
    let height: CGFloat
    let isVideoContent: Bool
    let onImageLoaded: ((Data) -> Void)?

    @State private var imageData: Data?
    @State private var isLoading: Bool = true

    private var isVideo: Bool {
        isVideoContent
    }

    init(
        imagePath: String,
        width: CGFloat,
        height: CGFloat,
        isVideo: Bool? = nil,
        onImageLoaded: ((Data) -> Void)? = nil
    ) {
        self.imagePath = imagePath
        self.width = width
        self.height = height
        self.isVideoContent = isVideo ?? MediaTypeHelper.isVideoPath(imagePath)
        self.onImageLoaded = onImageLoaded
    }

    var body: some View {
        ZStack {
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        }
                    }
            }

            // 동영상 아이콘
            if isVideo && imageData != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AppIcon.videoCircle
                            .foregroundStyle(.white)
                            .font(.system(size: width > 150 ? 30 : 20))
                            .padding(8)
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .task(id: imagePath) {
            await loadMedia()
        }
    }

    // MARK: - 미디어 로드
    private func loadMedia() async {
        do {
            // 캐시 확인 (메모리에서 즉시 조회, 매우 빠름)
            if let cachedData = await ImageCache.shared.get(imagePath) {
                imageData = cachedData
                onImageLoaded?(cachedData)
                isLoading = false
                return
            }

            let mediaData = try await NetworkManager.shared.download(
                MediaRouter.getData(path: imagePath)
            )

            // imagePath가 실제 비디오 파일이면 썸네일 생성, 아니면 그대로 사용
            if MediaTypeHelper.isVideoPath(imagePath) {
                // 비디오 파일 → 썸네일 생성
                if let thumbnailData = await VideoThumbnailHelper.generateThumbnail(from: mediaData) {
                    imageData = thumbnailData
                    onImageLoaded?(thumbnailData)
                    await ImageCache.shared.set(imagePath, data: thumbnailData)
                }
            } else {
                // 이미지 파일 → 그대로 사용
                imageData = mediaData
                onImageLoaded?(mediaData)
                await ImageCache.shared.set(imagePath, data: mediaData)
            }

            isLoading = false
        } catch is CancellationError {
            // Task가 취소되었을 때는 로그를 남기지 않음
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}
