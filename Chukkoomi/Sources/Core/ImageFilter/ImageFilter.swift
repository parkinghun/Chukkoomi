//
//  ImageFilter.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/19/25.
//

import UIKit
import CoreImage
import CoreML
import Metal

// MARK: - FilterError

/// 필터 적용 중 발생할 수 있는 에러
enum FilterError: Error, LocalizedError {
    case invalidImage
    case filterCreationFailed(String)
    case modelNotFound(String)
    case modelLoadFailed(String)
    case renderingFailed
    case pixelBufferCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "이미지를 CIImage로 변환할 수 없습니다."
        case .filterCreationFailed(let filterName):
            return "필터 생성 실패: \(filterName)"
        case .modelNotFound(let modelName):
            return "CoreML 모델을 찾을 수 없습니다: \(modelName)"
        case .modelLoadFailed(let modelName):
            return "CoreML 모델 로딩 실패: \(modelName)"
        case .renderingFailed:
            return "이미지 렌더링 실패"
        case .pixelBufferCreationFailed:
            return "PixelBuffer 생성 실패"
        }
    }
}

// MARK: - ImageFilter

/// 이미지 필터 타입
enum ImageFilter: String, CaseIterable, Identifiable, Codable {
    case original = "원본"
    case noir = "흑백"
    case chrome = "선명"
    case sepia = "빈티지"
    case vivid = "생생"
    case warm = "따뜻"
    case cool = "시원"
    case animeGANHayao = "애니메이션"
    case anime2sketch = "스케치"

    var id: String { rawValue }

    // MARK: - Shared Resources (앱 전체에서 재사용)

    /// GPU 가속 CIContext (Metal)
    /// - 생성 비용이 크므로 static let으로 앱 시작 시 1회만 생성
    /// - Metal 디바이스가 있으면 GPU 가속, 없으면 CPU 사용
    private static let sharedContext: CIContext = {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            // Metal GPU 사용 (10배 빠름)
            return CIContext(mtlDevice: metalDevice, options: [
                .useSoftwareRenderer: false,
                .priorityRequestLow: false
            ])
        } else {
            // Fallback: CPU 렌더링
            return CIContext(options: [.useSoftwareRenderer: false])
        }
    }()

    /// CoreML 모델 캐시 (Dictionary로 관리)
    /// - 앱 시작 시 필요한 모델만 lazy 로딩
    /// - 메모리 효율을 위해 Dictionary 사용
    private static var modelCache: [String: MLModel] = [:]

    /// CoreML 모델 로드 (캐싱)
    /// - Parameter modelName: 모델 이름
    /// - Returns: 로드된 MLModel
    private static func loadModel(named modelName: String) throws -> MLModel {
        // 캐시 확인
        if let cachedModel = modelCache[modelName] {
            return cachedModel
        }

        // 모델 파일 찾기
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            throw FilterError.modelNotFound(modelName)
        }

        // 모델 로딩
        let config = MLModelConfiguration()
        config.computeUnits = .all  // CPU + GPU + Neural Engine

        do {
            let model = try MLModel(contentsOf: modelURL, configuration: config)
            modelCache[modelName] = model  // 캐시 저장
            print("[ImageFilter] ✅ Model loaded: \(modelName)")
            return model
        } catch {
            throw FilterError.modelLoadFailed("\(modelName): \(error.localizedDescription)")
        }
    }

    // MARK: - Filter Application

    /// 이미지에 필터 적용
    /// - Parameter image: 원본 이미지
    /// - Returns: 필터가 적용된 이미지 (실패 시 nil)
    func apply(to image: UIImage) -> UIImage? {
        // CoreImage 필터
        switch self {
        case .original:
            return image

        case .noir, .chrome, .sepia, .vivid, .warm, .cool:
            return applyCoreImageFilter(to: image)

        case .animeGANHayao:
            return applyCoreMLStyleTransfer(
                to: image,
                modelName: "AnimeGANv3_Hayao_36_fp16",
                inputSize: CGSize(width: 512, height: 512)
            )

        case .anime2sketch:
            return applyCoreMLStyleTransfer(
                to: image,
                modelName: "anime2sketch",
                inputSize: CGSize(width: 512, height: 512)
            )
        }
    }

    // MARK: - CoreImage Filters

    /// CoreImage 필터 적용 (noir, chrome, sepia, vivid, warm, cool)
    private func applyCoreImageFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else {
            print("[ImageFilter] ❌ Failed to create CIImage")
            return nil
        }

        // 필터 생성
        let filter: CIFilter?

        switch self {
        case .noir:
            filter = CIFilter(name: "CIPhotoEffectNoir")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)

        case .chrome:
            filter = CIFilter(name: "CIPhotoEffectChrome")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)

        case .sepia:
            filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(0.8, forKey: kCIInputIntensityKey)

        case .vivid:
            filter = CIFilter(name: "CIColorControls")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(1.2, forKey: kCIInputSaturationKey)   // 채도 +20%
            filter?.setValue(0.15, forKey: kCIInputBrightnessKey)  // 밝기 +15%
            filter?.setValue(1.0, forKey: kCIInputContrastKey)     // 대비 유지

        case .warm:
            filter = CIFilter(name: "CITemperatureAndTint")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter?.setValue(CIVector(x: 7000, y: 100), forKey: "inputTargetNeutral")

        case .cool:
            filter = CIFilter(name: "CITemperatureAndTint")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter?.setValue(CIVector(x: 5500, y: -100), forKey: "inputTargetNeutral")

        default:
            return nil
        }

        guard let filter = filter,
              let outputImage = filter.outputImage else {
            print("[ImageFilter] ❌ Filter creation failed: \(self.rawValue)")
            return nil
        }

        // GPU 렌더링 (sharedContext 재사용)
        guard let cgImage = ImageFilter.sharedContext.createCGImage(
            outputImage,
            from: outputImage.extent
        ) else {
            print("[ImageFilter] ❌ CGImage creation failed")
            return nil
        }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    // MARK: - CoreML Style Transfer

    /// CoreML 스타일 변환 필터 적용 (AnimeGAN, anime2sketch)
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - modelName: CoreML 모델 이름
    ///   - inputSize: 모델 입력 크기 (512x512)
    /// - Returns: 변환된 이미지 (실패 시 원본 반환)
    private func applyCoreMLStyleTransfer(
        to image: UIImage,
        modelName: String,
        inputSize: CGSize
    ) -> UIImage? {

        guard let ciImage = CIImage(image: image) else {
            print("[ImageFilter] ❌ Failed to create CIImage")
            return image
        }

        do {
            // 1. 모델 로드 (캐시 사용)
            let mlModel = try ImageFilter.loadModel(named: modelName)

            // 2. 이미지 리사이즈 (모델 입력 크기에 맞춤)
            let originalSize = ciImage.extent.size
            let resized = ciImage.transformed(by: CGAffineTransform(
                scaleX: inputSize.width / originalSize.width,
                y: inputSize.height / originalSize.height
            ))

            // 3. CIImage → CVPixelBuffer
            guard let pixelBuffer = ImageFilter.createPixelBuffer(
                from: resized,
                size: inputSize
            ) else {
                throw FilterError.pixelBufferCreationFailed
            }

            // 4. 모델 입력 준비
            guard let inputName = mlModel.modelDescription.inputDescriptionsByName.keys.first else {
                throw FilterError.modelLoadFailed("Failed to get input name")
            }

            let provider = try MLDictionaryFeatureProvider(dictionary: [
                inputName: MLFeatureValue(pixelBuffer: pixelBuffer)
            ])

            // 5. 추론 실행
            let output = try mlModel.prediction(from: provider)

            // 6. 출력 추출
            guard let outputName = mlModel.modelDescription.outputDescriptionsByName.keys.first,
                  let outputPixelBuffer = output.featureValue(for: outputName)?.imageBufferValue else {
                throw FilterError.renderingFailed
            }

            var outputCI = CIImage(cvPixelBuffer: outputPixelBuffer)

            // 7. 원본 크기로 리사이즈
            outputCI = outputCI.transformed(by: CGAffineTransform(
                scaleX: originalSize.width / inputSize.width,
                y: originalSize.height / inputSize.height
            ))

            // 8. CIImage → UIImage (GPU 렌더링)
            guard let cgImage = ImageFilter.sharedContext.createCGImage(
                outputCI,
                from: outputCI.extent
            ) else {
                throw FilterError.renderingFailed
            }

            return UIImage(
                cgImage: cgImage,
                scale: image.scale,
                orientation: image.imageOrientation
            )

        } catch {
            print("[ImageFilter] ❌ CoreML filter failed: \(error.localizedDescription)")
            return image  // 실패 시 원본 반환
        }
    }

    // MARK: - PixelBuffer Creation

    /// CIImage를 CVPixelBuffer로 변환 (GPU 가속)
    /// - Parameters:
    ///   - image: 변환할 CIImage
    ///   - size: 버퍼 크기
    /// - Returns: 생성된 CVPixelBuffer
    private static func createPixelBuffer(
        from image: CIImage,
        size: CGSize
    ) -> CVPixelBuffer? {

        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true  // Metal GPU 호환
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("[ImageFilter] ❌ CVPixelBufferCreate failed: \(status)")
            return nil
        }

        // GPU 가속 렌더링 (sharedContext 재사용)
        sharedContext.render(image, to: buffer)

        return buffer
    }
}

// MARK: - FilterCacheManager

/// 필터 적용 결과를 캐싱하는 Actor (Thread-safe)
actor FilterCacheManager {

    // MARK: - Properties

    /// 썸네일 캐시 (200x200 크기)
    private var thumbnailCache: [String: UIImage] = [:]

    /// 전체 이미지 캐시 (원본 크기)
    private var fullImageCache: [String: UIImage] = [:]

    /// 캐시 크기 제한 (메모리 관리)
    private let maxThumbnailCacheSize = 50  // 최대 50개
    private let maxFullImageCacheSize = 10  // 최대 10개

    // MARK: - Thumbnail Cache

    func getThumbnail(for key: String) -> UIImage? {
        thumbnailCache[key]
    }

    func setThumbnail(_ image: UIImage, for key: String) {
        // LRU 캐시: 크기 초과 시 가장 오래된 항목 제거
        if thumbnailCache.count >= maxThumbnailCacheSize {
            thumbnailCache.removeValue(forKey: thumbnailCache.keys.first!)
        }
        thumbnailCache[key] = image
    }

    // MARK: - Full Image Cache

    func getFullImage(for key: String) -> UIImage? {
        fullImageCache[key]
    }

    func setFullImage(_ image: UIImage, for key: String) {
        // LRU 캐시: 크기 초과 시 가장 오래된 항목 제거
        if fullImageCache.count >= maxFullImageCacheSize {
            fullImageCache.removeValue(forKey: fullImageCache.keys.first!)
        }
        fullImageCache[key] = image
    }

    // MARK: - Cache Management

    func clearAll() {
        thumbnailCache.removeAll()
        fullImageCache.removeAll()
        print("[FilterCacheManager] 🗑️ All cache cleared")
    }

    func clearThumbnailCache() {
        thumbnailCache.removeAll()
        print("[FilterCacheManager] 🗑️ Thumbnail cache cleared")
    }

    func clearFullImageCache() {
        fullImageCache.removeAll()
        print("[FilterCacheManager] 🗑️ Full image cache cleared")
    }

    /// 메모리 경고 시 호출
    func handleMemoryWarning() {
        // 전체 이미지 캐시만 클리어 (썸네일은 유지)
        clearFullImageCache()
    }
}
