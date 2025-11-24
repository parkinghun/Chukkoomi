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

    /// 필터 설명
    var description: String {
        switch self {
        case .original:
            return "필터 없음"
        case .noir:
            return "흑백 + 대비"
        case .chrome:
            return "선명한 색감"
        case .sepia:
            return "따뜻한 빈티지"
        case .vivid:
            return "밝고 화사한"
        case .warm:
            return "따뜻한 색조"
        case .cool:
            return "시원한 색조"
        case .animeGANHayao:
            return "애니메이션"
        case .anime2sketch:
            return "스케치"
        }
    }

    /// 이미지에 필터 적용
    /// - Parameter image: 원본 이미지
    /// - Returns: 필터가 적용된 이미지
    func apply(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else {
            return nil
        }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        var filteredImage: CIImage?

        switch self {
        case .original:
            return image

        case .noir:
            // 흑백 + 대비
            guard let filter = CIFilter(name: "CIPhotoEffectNoir") else {
                return nil
            }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage

        case .chrome:
            // 선명한 색감
            guard let filter = CIFilter(name: "CIPhotoEffectChrome") else {
                return nil
            }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filteredImage = filter.outputImage

        case .sepia:
            // 따뜻한 빈티지
            guard let filter = CIFilter(name: "CISepiaTone") else {
                return nil
            }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(0.8, forKey: kCIInputIntensityKey)
            filteredImage = filter.outputImage

        case .vivid:
            // 밝고 화사한 (채도 + 밝기)
            guard let filter = CIFilter(name: "CIColorControls") else {
                return nil
            }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.2, forKey: kCIInputSaturationKey)  // 채도 증가
            filter.setValue(0.15, forKey: kCIInputBrightnessKey) // 밝기 증가
            filter.setValue(1.0, forKey: kCIInputContrastKey)    // 대비 유지
            filteredImage = filter.outputImage

        case .warm:
            // 따뜻한 색조 (온도 조절)
            guard let temperatureFilter = CIFilter(name: "CITemperatureAndTint") else {
                return nil
            }
            temperatureFilter.setValue(ciImage, forKey: kCIInputImageKey)
            temperatureFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            temperatureFilter.setValue(CIVector(x: 7000, y: 100), forKey: "inputTargetNeutral")
            filteredImage = temperatureFilter.outputImage

        case .cool:
            // 시원한 색조 (온도 조절)
            guard let temperatureFilter = CIFilter(name: "CITemperatureAndTint") else {
                return nil
            }
            temperatureFilter.setValue(ciImage, forKey: kCIInputImageKey)
            temperatureFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            temperatureFilter.setValue(CIVector(x: 5500, y: -100), forKey: "inputTargetNeutral")
            filteredImage = temperatureFilter.outputImage
            
        case .animeGANHayao:
            return ImageFilter.applyCoreMLStyleTransfer(
                to: image,
                modelName: "AnimeGANv3_Hayao_36_fp16",
                inputSize: CGSize(width: 512, height: 512)
            )

        case .anime2sketch:
            return ImageFilter.applyCoreMLStyleTransfer(
                to: image,
                modelName: "anime2sketch",
                inputSize: CGSize(width: 512, height: 512)
            )
        }

        guard let outputImage = filteredImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - AnimeGAN Helper Methods

    /// GPU 가속 CIContext (재사용)
    private static let gpuContext: CIContext = {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            // Metal GPU 사용
            return CIContext(mtlDevice: metalDevice, options: [
                .useSoftwareRenderer: false,
                .priorityRequestLow: false
            ])
        } else {
            // Metal 사용 불가시 기본 컨텍스트
            return CIContext(options: [.useSoftwareRenderer: false])
        }
    }()

    /// AnimeGAN 모델 캐시 (재사용)
    private static let animeGANModel: MLModel? = {
        guard let modelURL = Bundle.main.url(forResource: "AnimeGANv3_Hayao_36_fp16", withExtension: "mlmodelc") else {
            print("[Error] AnimeGANv3_Hayao_36_fp16.mlmodelc not found")
            return nil
        }

        do {
            // GPU 사용 설정
            let config = MLModelConfiguration()
            config.computeUnits = .all  // CPU, GPU, Neural Engine 모두 사용

            return try MLModel(contentsOf: modelURL, configuration: config)
        } catch {
            print("[Error] Failed to load AnimeGAN model: \(error)")
            return nil
        }
    }()

    static func applyCoreMLStyleTransfer(
        to image: UIImage,
        modelName: String,
        inputSize: CGSize
    ) -> UIImage? {

        guard let ciImage = CIImage(image: image) else { return nil }

        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            print("[Error] MLModel not found: \(modelName)")
            return image
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all

        guard let mlModel = try? MLModel(contentsOf: modelURL, configuration: config) else {
            print("[Error] Failed to load MLModel: \(modelName)")
            return image
        }

        // 1. Resize to model input
        let originalSize = ciImage.extent.size
        let resized = ciImage.transformed(by: CGAffineTransform(
            scaleX: inputSize.width / originalSize.width,
            y: inputSize.height / originalSize.height
        ))

        guard let pixelBuffer = createPixelBuffer(from: resized, size: inputSize) else { return image }

        guard let inputName = mlModel.modelDescription.inputDescriptionsByName.keys.first else {
            print("[Error] Failed to get input name")
            return image
        }

        let provider = try? MLDictionaryFeatureProvider(dictionary: [
            inputName : MLFeatureValue(pixelBuffer: pixelBuffer)
        ])

        guard let output = try? mlModel.prediction(from: provider!) else {
            print("[Error] Prediction failed")
            return image
        }

        let outputName = mlModel.modelDescription.outputDescriptionsByName.keys.first!
        guard let outputPixelBuffer = output.featureValue(for: outputName)?.imageBufferValue else {
            print("[Error] Failed to get output image")
            return image
        }

        var outputCI = CIImage(cvPixelBuffer: outputPixelBuffer)

        // 2. Resize back to original size
        outputCI = outputCI.transformed(by: CGAffineTransform(
            scaleX: originalSize.width / inputSize.width,
            y: originalSize.height / inputSize.height
        ))

        guard let cg = gpuContext.createCGImage(outputCI, from: outputCI.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }

    /// CIImage를 CVPixelBuffer로 변환 (GPU 가속)
    private static func createPixelBuffer(from image: CIImage, size: CGSize) -> CVPixelBuffer? {
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true  // Metal 호환성
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
            return nil
        }

        // GPU 가속 컨텍스트 사용
        gpuContext.render(image, to: buffer)

        return buffer
    }

    /// MLMultiArray를 CVPixelBuffer로 변환 (rank-3 tensor용 - 성능 최적화)
    private static func createPixelBuffer(from multiArray: MLMultiArray, size: CGSize) -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)

        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("[Error] AnimeGAN: Failed to create pixel buffer")
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            print("[Error] AnimeGAN: Failed to get pixel buffer base address")
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let bufferPointer = baseAddress.assumingMemoryBound(to: UInt8.self)

        // MLMultiArray의 데이터 포인터 직접 접근 (성능 최적화)
        let shape = multiArray.shape.map { $0.intValue }
        let strides = multiArray.strides.map { $0.intValue }

        // dataPointer를 Float 타입으로 바인딩 (대부분의 모델은 Float32 출력)
        let dataPointer = UnsafeMutablePointer<Float>(OpaquePointer(multiArray.dataPointer))

        // shape 확인: [channels, height, width] 또는 [height, width, channels]
        let isChannelsFirst = shape.count == 3 && shape[0] == 3

        if isChannelsFirst {
            // [channels, height, width] 형식 - 더 빠른 변환
            let channelStride = strides[0]
            let heightStride = strides[1]
            let widthStride = strides[2]

            for y in 0..<height {
                for x in 0..<width {
                    let baseIdx = y * heightStride + x * widthStride

                    let r = dataPointer[baseIdx]
                    let g = dataPointer[baseIdx + channelStride]
                    let b = dataPointer[baseIdx + channelStride * 2]

                    // 값이 [0, 1] 범위면 255로 스케일
                    let scale: Float = (r <= 1.0 && g <= 1.0 && b <= 1.0) ? 255.0 : 1.0

                    let rByte = UInt8(max(0, min(255, r * scale)))
                    let gByte = UInt8(max(0, min(255, g * scale)))
                    let bByte = UInt8(max(0, min(255, b * scale)))

                    // BGRA 형식으로 저장
                    let offset = y * bytesPerRow + x * 4
                    bufferPointer[offset] = bByte     // B
                    bufferPointer[offset + 1] = gByte // G
                    bufferPointer[offset + 2] = rByte // R
                    bufferPointer[offset + 3] = 255   // A
                }
            }
        } else {
            // [height, width, channels] 형식
            let heightStride = strides[0]
            let widthStride = strides[1]
            let channelStride = strides[2]

            for y in 0..<height {
                for x in 0..<width {
                    let baseIdx = y * heightStride + x * widthStride

                    let r = dataPointer[baseIdx]
                    let g = dataPointer[baseIdx + channelStride]
                    let b = dataPointer[baseIdx + channelStride * 2]

                    // 값이 [0, 1] 범위면 255로 스케일
                    let scale: Float = (r <= 1.0 && g <= 1.0 && b <= 1.0) ? 255.0 : 1.0

                    let rByte = UInt8(max(0, min(255, r * scale)))
                    let gByte = UInt8(max(0, min(255, g * scale)))
                    let bByte = UInt8(max(0, min(255, b * scale)))

                    // BGRA 형식으로 저장
                    let offset = y * bytesPerRow + x * 4
                    bufferPointer[offset] = bByte     // B
                    bufferPointer[offset + 1] = gByte // G
                    bufferPointer[offset + 2] = rByte // R
                    bufferPointer[offset + 3] = 255   // A
                }
            }
        }

        return buffer
    }
}

/// 필터 적용 결과를 캐싱하는 매니저
actor FilterCacheManager {
    private var thumbnailCache: [String: UIImage] = [:]
    private var fullImageCache: [String: UIImage] = [:]

    func getThumbnail(for key: String) -> UIImage? {
        thumbnailCache[key]
    }

    func setThumbnail(_ image: UIImage, for key: String) {
        thumbnailCache[key] = image
    }

    func getFullImage(for key: String) -> UIImage? {
        fullImageCache[key]
    }

    func setFullImage(_ image: UIImage, for key: String) {
        fullImageCache[key] = image
    }

    func clearAll() {
        thumbnailCache.removeAll()
        fullImageCache.removeAll()
    }
}
