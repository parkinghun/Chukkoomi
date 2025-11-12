//
//  CompressHelper.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/11/25.
//

import UIKit

enum CompressHelper {
    
    static func compressImage(_ imageData: Data, maxSizeInBytes: Int, maxWidth: CGFloat, maxHeight: CGFloat) async -> Data? {
        // 이미지 리사이징
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        
        var resizedImage = image
        
        if image.size.width > maxWidth || image.size.height > maxHeight {
            let ratio = min(maxWidth / image.size.width, maxHeight / image.size.height)
            let newSize = CGSize(
                width: image.size.width * ratio,
                height: image.size.height * ratio
            )

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let scaledImage = UIGraphicsGetImageFromCurrentImageContext() {
                resizedImage = scaledImage
            }
            UIGraphicsEndImageContext()
        }
        
        // 압축 품질 조정
        var compression: CGFloat = 0.8
        let minCompression: CGFloat = 0.1
        let step: CGFloat = 0.1

        guard var imageData = resizedImage.jpegData(compressionQuality: compression) else {
            return nil
        }

        // 이미 maxSize 이하면 그대로 반환
        if imageData.count <= maxSizeInBytes {
            return imageData
        }
        
        // 압축 품질을 점진적으로 낮추면서 maxSize 이하로 만들기
        while imageData.count > maxSizeInBytes && compression > minCompression {
            compression -= step
            if let compressedData = resizedImage.jpegData(compressionQuality: max(compression, minCompression)) {
                imageData = compressedData
            } else {
                break
            }
        }

        return imageData
    }
}
