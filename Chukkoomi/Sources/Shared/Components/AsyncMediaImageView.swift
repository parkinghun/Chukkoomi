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
    let onImageLoaded: ((Data) -> Void)?

    @State private var imageData: Data?
    @State private var isLoading: Bool = true

    private var isVideo: Bool {
        MediaTypeHelper.isVideoPath(imagePath)
    }

    init(
        imagePath: String,
        width: CGFloat,
        height: CGFloat,
        onImageLoaded: ((Data) -> Void)? = nil
    ) {
        self.imagePath = imagePath
        self.width = width
        self.height = height
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

            let mediaData: Data

            // TODO: picsum 테스트용 임시 코드 - 나중에 삭제
            if imagePath.hasPrefix("http://") || imagePath.hasPrefix("https://") {
                // 외부 URL: URLSession으로 직접 다운로드
                guard let url = URL(string: imagePath) else {
                    isLoading = false
                    return
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                mediaData = data
            } else {
                // 실제 사용 코드
                mediaData = try await NetworkManager.shared.download(
                    MediaRouter.getData(path: imagePath)
                )
            }

            // 원래 코드 (picsum 테스트 후 복원)
            // let mediaData = try await NetworkManager.shared.download(
            //     MediaRouter.getData(path: imagePath)
            // )

            if isVideo {
                // 동영상이면 썸네일 추출
                if let thumbnailData = await VideoThumbnailHelper.generateThumbnail(from: mediaData) {
                    imageData = thumbnailData
                    onImageLoaded?(thumbnailData)
                    // 캐시에 저장
                    await ImageCache.shared.set(imagePath, data: thumbnailData)
                }
            } else {
                // 이미지는 그대로 사용
                imageData = mediaData
                onImageLoaded?(mediaData)
                // 캐시에 저장
                await ImageCache.shared.set(imagePath, data: mediaData)
            }

            isLoading = false
        } catch is CancellationError {
            // Task가 취소되었을 때는 로그를 남기지 않음
            isLoading = false
        } catch {
            print("미디어 로드 실패: \(error)")
            isLoading = false
        }
    }
}
