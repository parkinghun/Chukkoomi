//
//  VideoFilterHelper.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/20/25.
//

import Foundation
@preconcurrency import CoreImage
import CoreML
import Metal

/// 비디오 필터 적용 헬퍼 (공통 로직)
enum VideoFilterHelper {

    /// CIImage에 필터 적용
    /// - Parameters:
    ///   - filter: 적용할 필터
    ///   - image: 원본 이미지
    ///   - originalImage: ML 모델용 원본 이미지 (clamped되지 않은)
    ///   - targetSize: 목표 크기 (AnimeGAN 필터용, nil이면 원본 크기)
    /// - Returns: 필터가 적용된 이미지
    static func applyFilter(_ filter: VideoFilter, to image: CIImage, originalImage: CIImage? = nil, targetSize: CGSize? = nil) -> CIImage {
        switch filter {
        case .blackAndWhite:
            return applyBlackAndWhiteFilter(to: image)
        case .warm:
            return applyWarmFilter(to: image)
        case .cool:
            return applyCoolFilter(to: image)
        case .animeGANHayao:
            return applyAnimeGANHayao(to: originalImage ?? image, targetSize: targetSize)
        }
    }

    // MARK: - Private Filter Methods

    /// 흑백 필터 적용
    private static func applyBlackAndWhiteFilter(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIPhotoEffectMono") else {
            return image
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }

    /// 따뜻한 필터 적용
    private static func applyWarmFilter(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else {
            return image
        }

        // 색온도를 높여서 따뜻한 느낌 (오렌지/노란 톤)
        let warmVector = CIVector(x: 8000, y: 0)
        let neutralVector = CIVector(x: 6500, y: 0)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(warmVector, forKey: "inputNeutral")
        filter.setValue(neutralVector, forKey: "inputTargetNeutral")

        return filter.outputImage ?? image
    }

    /// 차가운 필터 적용
    private static func applyCoolFilter(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else {
            return image
        }

        // 색온도를 낮춰서 차가운 느낌 (파란 톤)
        let coolVector = CIVector(x: 5000, y: 0)
        let neutralVector = CIVector(x: 6500, y: 0)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(coolVector, forKey: "inputNeutral")
        filter.setValue(neutralVector, forKey: "inputTargetNeutral")

        return filter.outputImage ?? image
    }

    /// AnimeGANv3 CoreML 필터 적용
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - targetSize: 목표 크기 (nil이면 원본 크기)
    /// - Returns: 필터가 적용된 이미지
    private static func applyAnimeGANHayao(to image: CIImage, targetSize: CGSize? = nil) -> CIImage {
        // extent 유효성 검사
        guard image.extent.width > 0 && image.extent.height > 0,
              image.extent.width.isFinite && image.extent.height.isFinite else {
            print("[Error] AnimeGAN: Invalid image extent: \(image.extent)")
            return image
        }

        // 캐싱된 모델 사용
        guard let mlModel = animeGANModel else {
            print("[Error] AnimeGAN model not available")
            return image
        }

        do {
            // 모델 입력 이름 가져오기
            guard let inputName = mlModel.modelDescription.inputDescriptionsByName.keys.first else {
                print("[Error] AnimeGAN: Failed to get input name")
                return image
            }

            // AnimeGAN 입력 크기는 512x512로 고정
            let modelSize = CGSize(width: 512, height: 512)

            // 목표 크기 결정: targetSize가 제공되면 사용, 아니면 원본 크기
            let finalSize = targetSize ?? image.extent.size

            // 이미지를 모델 입력 크기로 리사이즈
            let scaleX = modelSize.width / image.extent.width
            let scaleY = modelSize.height / image.extent.height
            let resizedImage = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            // CIImage를 CVPixelBuffer로 변환
            guard let inputPixelBuffer = createPixelBuffer(from: resizedImage, size: modelSize) else {
                print("[Error] AnimeGAN: Failed to create input pixel buffer")
                return image
            }

            // MLFeatureProvider 생성
            let input = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: inputPixelBuffer)])

            // 모델 실행
            let output = try mlModel.prediction(from: input)

            // 출력 이름 가져오기
            let outputName = mlModel.modelDescription.outputDescriptionsByName.keys.first ?? "Identity"

            // 출력 데이터 가져오기
            var outputImage: CIImage

            // imageBufferValue 시도
            if let outputPixelBuffer = output.featureValue(for: outputName)?.imageBufferValue {
                outputImage = CIImage(cvPixelBuffer: outputPixelBuffer)
            }
            // multiArrayValue로 폴백
            else if let multiArray = output.featureValue(for: outputName)?.multiArrayValue {
                guard let pixelBuffer = createPixelBuffer(from: multiArray, size: modelSize) else {
                    print("[Error] AnimeGAN: Failed to create pixel buffer from multi array")
                    return image
                }
                outputImage = CIImage(cvPixelBuffer: pixelBuffer)
            } else {
                print("[Error] AnimeGAN: Failed to get output data")
                return image
            }

            // 목표 크기로 리사이징
            let scaleBackX = finalSize.width / outputImage.extent.width
            let scaleBackY = finalSize.height / outputImage.extent.height
            outputImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleBackX, y: scaleBackY))

            return outputImage
        } catch {
            print("[Error] AnimeGAN CoreML processing failed: \(error)")
            return image
        }
    }

    // MARK: - GPU Context & Model Cache

    /// GPU 가속 CIContext (재사용)
    static let gpuContext: CIContext = {
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

    // MARK: - Helper Methods

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
