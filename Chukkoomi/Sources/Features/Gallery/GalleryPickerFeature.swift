//
//  GalleryPickerFeature.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/10/25.
//

import ComposableArchitecture
import Foundation
import Photos
import UIKit

@Reducer
struct GalleryPickerFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var mediaItems: [MediaItem] = []
        var selectedItem: MediaItem?
        var selectedImage: UIImage?
        var authorizationStatus: PHAuthorizationStatus = .notDetermined
        var isLoading: Bool = false
        var isLoadingMore: Bool = false
        var hasMoreItems: Bool = true
        var currentOffset: Int = 0
        var pickerMode: PickerMode = .profileImage
        @Presents var editVideo: EditVideoFeature.State?
        @Presents var editPhoto: EditPhotoFeature.State?
    }

    // MARK: - PickerMode
    enum PickerMode: Equatable {
        case profileImage  // 프로필 사진: "완료", 사진만
        case post          // 게시물: "다음", 사진+영상

        var buttonTitle: String {
            switch self {
            case .profileImage:
                return "완료"
            case .post:
                return "다음"
            }
        }

        var allowsVideo: Bool {
            switch self {
            case .profileImage:
                return false
            case .post:
                return true
            }
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case onAppear
        case requestPhotoLibraryAccess
        case authorizationStatusReceived(PHAuthorizationStatus)
        case loadMediaItems
        case loadMoreMediaItems
        case mediaItemsLoaded([MediaItem], hasMore: Bool)
        case mediaItemSelected(MediaItem)
        case selectedImageLoaded(UIImage)
        case confirmSelection
        case cancel
        case editVideo(PresentationAction<EditVideoFeature.Action>)
        case editPhoto(PresentationAction<EditPhotoFeature.Action>)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didSelectImage(Data)
            case didSelectVideo(PHAsset)
            case didExportVideo(URL)
        }
    }

    // MARK: - Body
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                state.authorizationStatus = status

                if status == .authorized || status == .limited {
                    return .send(.loadMediaItems)
                } else if status == .notDetermined {
                    return .send(.requestPhotoLibraryAccess)
                }
                return .none

            case .requestPhotoLibraryAccess:
                return .run { send in
                    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    await send(.authorizationStatusReceived(status))
                }

            case .authorizationStatusReceived(let status):
                state.authorizationStatus = status
                if status == .authorized || status == .limited {
                    return .send(.loadMediaItems)
                }
                return .none

            case .loadMediaItems:
                state.isLoading = true
                state.currentOffset = 0
                state.mediaItems = []
                return .run { [allowsVideo = state.pickerMode.allowsVideo] send in
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

                    let pageSize = 50
                    let allAssets = PHAsset.fetchAssets(with: fetchOptions)
                    let totalCount = allAssets.count

                    var mediaItems: [MediaItem] = []
                    let endIndex = min(pageSize, totalCount)

                    for i in 0..<endIndex {
                        let asset = allAssets.object(at: i)
                        if !allowsVideo && asset.mediaType != .image {
                            continue
                        }
                        mediaItems.append(MediaItem(asset: asset))
                    }

                    let hasMore = endIndex < totalCount
                    await send(.mediaItemsLoaded(mediaItems, hasMore: hasMore))
                }

            case .loadMoreMediaItems:
                guard state.hasMoreItems && !state.isLoadingMore else {
                    return .none
                }

                state.isLoadingMore = true
                return .run { [allowsVideo = state.pickerMode.allowsVideo, offset = state.currentOffset] send in
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

                    let pageSize = 50
                    let allAssets = PHAsset.fetchAssets(with: fetchOptions)
                    let totalCount = allAssets.count

                    let startIndex = offset + pageSize
                    let endIndex = min(startIndex + pageSize, totalCount)

                    var mediaItems: [MediaItem] = []
                    for i in startIndex..<endIndex {
                        let asset = allAssets.object(at: i)
                        if !allowsVideo && asset.mediaType != .image {
                            continue
                        }
                        mediaItems.append(MediaItem(asset: asset))
                    }

                    let hasMore = endIndex < totalCount
                    await send(.mediaItemsLoaded(mediaItems, hasMore: hasMore))
                }

            case .mediaItemsLoaded(let items, let hasMore):
                if state.isLoading {
                    state.mediaItems = items
                    state.currentOffset = 0
                } else {
                    state.mediaItems.append(contentsOf: items)
                    state.currentOffset += 50
                }
                state.hasMoreItems = hasMore
                state.isLoading = false
                state.isLoadingMore = false
                return .none

            case .mediaItemSelected(let item):
                state.selectedItem = item

                return .run { send in
                    let image = await self.loadImage(from: item.asset)
                    if let image = image {
                        await send(.selectedImageLoaded(image))
                    }
                }

            case .selectedImageLoaded(let image):
                state.selectedImage = image
                return .none

            case .confirmSelection:
                // pickerMode가 .post인 경우: navigation push
                if state.pickerMode == .post {
                    if let selectedItem = state.selectedItem, selectedItem.mediaType == .video {
                        // 동영상 선택 시 EditVideoView로 push
                        state.editVideo = EditVideoFeature.State(videoAsset: selectedItem.asset)
                        return .none
                    } else if let selectedImage = state.selectedImage {
                        // 사진 선택 시 EditPhotoView로 push
                        state.editPhoto = EditPhotoFeature.State(originalImage: selectedImage)
                        return .none
                    }
                    return .none
                }

                // profileImage 모드: delegate로 전달하고 dismiss
                guard let selectedImage = state.selectedImage,
                      let imageData = selectedImage.jpegData(compressionQuality: 0.8) else {
                    return .none
                }

                return .run { send in
                    await send(.delegate(.didSelectImage(imageData)))
                    await self.dismiss()
                }

            case .cancel:
                return .run { _ in
                    await self.dismiss()
                }

            case let .editVideo(.presented(.delegate(.videoExportCompleted(url)))):
                // 편집 완료된 영상을 PostCreateFeature로 전달하고 fullscreen 닫기
                // editVideo state를 먼저 nil로 설정
                state.editVideo = nil
                return .run { send in
                    await send(.delegate(.didExportVideo(url)))
                    await self.dismiss()
                }

            case .editVideo:
                return .none

            case let .editPhoto(.presented(.delegate(.didCompleteEditing(imageData)))):
                // 사진 편집 완료 - PostCreateFeature로 전달하고 fullscreen 닫기
                state.editPhoto = nil
                return .run { send in
                    await send(.delegate(.didSelectImage(imageData)))
                    await self.dismiss()
                }

            case .editPhoto:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$editVideo, action: \.editVideo) {
            EditVideoFeature()
        }
        .ifLet(\.$editPhoto, action: \.editPhoto) {
            EditPhotoFeature()
        }
    }

    // MARK: - Helper
    private func loadImage(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - Models
extension GalleryPickerFeature {
    struct MediaItem: Equatable, Identifiable {
        let id: String
        let asset: PHAsset
        let mediaType: PHAssetMediaType
        let duration: TimeInterval?

        init(asset: PHAsset) {
            self.id = asset.localIdentifier
            self.asset = asset
            self.mediaType = asset.mediaType
            self.duration = asset.mediaType == .video ? asset.duration : nil
        }

        static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
            lhs.id == rhs.id
        }
    }
}
