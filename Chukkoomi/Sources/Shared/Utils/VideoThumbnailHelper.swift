//
//  VideoThumbnailHelper.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import AVFoundation
import UIKit

/// 동영상 썸네일 추출을 순차적으로 처리하는 Actor
actor VideoThumbnailExtractor {
    static let shared = VideoThumbnailExtractor()

    private init() {}

    /// 동영상 데이터에서 썸네일 이미지를 추출 (순차 처리)
    func generateThumbnail(from videoData: Data) async -> Data? {
        // 임시 파일로 저장
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        do {
            try videoData.write(to: tempURL)

            // URL 버전 함수 재사용
            let thumbnailData = await generateThumbnail(from: tempURL)

            // 임시 파일 삭제
            try? FileManager.default.removeItem(at: tempURL)

            return thumbnailData
        } catch {
            print("썸네일 생성 실패: \(error)")
            // 임시 파일 삭제 시도
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }

    /// 동영상 URL에서 썸네일 이미지를 추출 (순차 처리)
    func generateThumbnail(from videoURL: URL) async -> Data? {
        do {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 800, height: 800)

            // 첫 프레임 추출 (0초)
            let time = CMTime(seconds: 0, preferredTimescale: 1)
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)

            // JPEG 데이터로 변환
            return uiImage.jpegData(compressionQuality: 0.8)
        } catch {
            print("썸네일 생성 실패: \(error)")
            return nil
        }
    }
}

enum VideoThumbnailHelper {
    /// 동영상 데이터에서 썸네일 이미지를 추출
    static func generateThumbnail(from videoData: Data) async -> Data? {
        await VideoThumbnailExtractor.shared.generateThumbnail(from: videoData)
    }

    /// 동영상 URL에서 썸네일 이미지를 추출
    static func generateThumbnail(from videoURL: URL) async -> Data? {
        await VideoThumbnailExtractor.shared.generateThumbnail(from: videoURL)
    }
}
