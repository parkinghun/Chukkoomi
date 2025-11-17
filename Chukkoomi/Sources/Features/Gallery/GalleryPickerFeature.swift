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
        var pickerMode: PickerMode = .profileImage
        @Presents var editVideo: EditVideoFeature.State?
        @Presents var editPhoto: EditPhotoState?
    }

    struct EditPhotoState: Equatable {
        // EditPhotoView용 임시 state
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
        case mediaItemsLoaded([MediaItem])
        case mediaItemSelected(MediaItem)
        case selectedImageLoaded(UIImage)
        case confirmSelection
        case cancel
        case editVideo(PresentationAction<EditVideoFeature.Action>)
        case editPhoto(PresentationAction<Never>)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didSelectImage(Data)
            case didSelectVideo(PHAsset)
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
                return .run { [allowsVideo = state.pickerMode.allowsVideo] send in
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    fetchOptions.fetchLimit = 100

                    let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
                    var mediaItems: [MediaItem] = []

                    fetchResult.enumerateObjects { asset, _, _ in
                        // allowsVideo가 false면 사진만 필터링
                        if !allowsVideo && asset.mediaType != .image {
                            return
                        }
                        mediaItems.append(MediaItem(asset: asset))
                    }

                    await send(.mediaItemsLoaded(mediaItems))
                }

            case .mediaItemsLoaded(let items):
                state.mediaItems = items
                state.isLoading = false
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
                    } else if state.selectedImage != nil {
                        // 사진 선택 시 EditPhotoView로 push
                        state.editPhoto = EditPhotoState()
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

            case .editVideo:
                return .none

            case .editPhoto:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$editVideo, action: \.editVideo) {
            EditVideoFeature()
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
