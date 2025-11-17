//
//  VideoFilterManager.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/15/25.
//

import UIKit
import AVFoundation
@preconcurrency import CoreImage
import Vision
import CoreML
import Metal

/// 비디오 필터 타입
enum VideoFilter: String, CaseIterable, Equatable {
    case blackAndWhite = "흑백"
    case warm = "따뜻한"
    case cool = "차갑게"
    case animeGANHayao = "Hayao"

    var displayName: String {
        return rawValue
    }
}

/// 비디오 필터 관리자
struct VideoFilterManager {

    /// 비디오에 필터를 적용한 AVVideoComposition 생성
    /// - Parameters:
    ///   - asset: 원본 비디오 AVAsset
    ///   - filter: 적용할 필터
    /// - Returns: 필터가 적용된 AVVideoComposition (필터가 없으면 nil)
    static func createVideoComposition(
        for asset: AVAsset,
        filter: VideoFilter?
    ) async -> AVVideoComposition? {
        // 필터가 없으면 nil 반환
        guard let filter = filter else {
            return nil
        }

        // 비디오 트랙 가져오기
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let naturalSize = try? await videoTrack.load(.naturalSize)
        let preferredTransform = try? await videoTrack.load(.preferredTransform)

        // AVVideoComposition 생성 (GPU 가속 컨텍스트 사용)
        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                let source = request.sourceImage
                let clampedSource = source.clampedToExtent()

                // 필터별로 CIFilter 생성 및 적용 (원본과 clamped 버전 모두 전달)
                let output = applyFilter(filter, to: clampedSource, originalImage: source)

                // GPU 가속 컨텍스트를 명시적으로 전달
                request.finish(with: output, context: gpuContext)
            }
        )

        // naturalSize 설정
        if let naturalSize = naturalSize {
            composition.renderSize = naturalSize
        }

        // Transform 처리 (회전, 플립 등)
        if let preferredTransform = preferredTransform {
            let videoInfo = orientation(from: preferredTransform)
            var isPortrait = false
            switch videoInfo.orientation {
            case .up, .upMirrored, .down, .downMirrored:
                isPortrait = false
            case .left, .leftMirrored, .right, .rightMirrored:
                isPortrait = true
            @unknown default:
                isPortrait = false
            }

            if isPortrait, let naturalSize = naturalSize {
                composition.renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            }
        }

        return composition
    }

    // MARK: - Private Helper Methods

    /// CIImage에 필터 적용
    /// - Parameters:
    ///   - filter: 적용할 필터
    ///   - image: clamped 이미지 (대부분의 필터용)
    ///   - originalImage: 원본 이미지 (ML 모델용)
    /// - Returns: 필터가 적용된 이미지
    private static func applyFilter(_ filter: VideoFilter, to image: CIImage, originalImage: CIImage) -> CIImage {
        switch filter {
        case .blackAndWhite:
            return applyBlackAndWhiteFilter(to: image)
        case .warm:
            return applyWarmFilter(to: image)
        case .cool:
            return applyCoolFilter(to: image)
        case .animeGANHayao:
            return applyAnimeGANHayao(to: originalImage)
        }
    }

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
        // neutral: (6500, 0) - 일반적인 색온도
        // warm: (8000, 0) - 따뜻한 색온도
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
        // neutral: (6500, 0) - 일반적인 색온도
        // cool: (5000, 0) - 차가운 색온도
        let coolVector = CIVector(x: 5000, y: 0)
        let neutralVector = CIVector(x: 6500, y: 0)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(coolVector, forKey: "inputNeutral")
        filter.setValue(neutralVector, forKey: "inputTargetNeutral")

        return filter.outputImage ?? image
    }
    
    /// AnimeGANv3 CoreML 필터 적용
    private static func applyAnimeGANHayao(to image: CIImage) -> CIImage {
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

            // 모델의 입력 크기 가져오기
            guard let inputName = mlModel.modelDescription.inputDescriptionsByName.keys.first,
                  let inputDescription = mlModel.modelDescription.inputDescriptionsByName[inputName],
                  let imageConstraint = inputDescription.imageConstraint else {
                print("[Error] AnimeGAN: Failed to get input description")
                return image
            }

            // 모델이 허용하는 입력 크기 결정 (512 고정 필요)
            let modelSize: CGSize
            let width = imageConstraint.pixelsWide
            let height = imageConstraint.pixelsHigh

            if width > 0 && height > 0 {
                // 고정 크기
                modelSize = CGSize(width: width, height: height)
            } else {
                // 가변 크기인 경우 512x512 사용
                modelSize = CGSize(width: 512, height: 512)
            }

            print("[Info] AnimeGAN: Using model input size: \(modelSize)")

            // 원본 이미지 크기 저장
            let originalSize = image.extent.size

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

            // 원본 크기로 복원
            let scaleBackX = originalSize.width / outputImage.extent.width
            let scaleBackY = originalSize.height / outputImage.extent.height
            outputImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleBackX, y: scaleBackY))

            return outputImage
        } catch {
            print("[Error] AnimeGAN CoreML processing failed: \(error)")
            return image
        }
    }

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
        guard let modelURL = Bundle.main.url(forResource: "AnimeGANv3_Hayao_36", withExtension: "mlmodelc") else {
            print("[Error] AnimeGANv3_Hayao_36.mlmodelc not found")
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

    /// 비디오 orientation 확인 헬퍼
    private static func orientation(from transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false

        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .down
        }

        return (assetOrientation, isPortrait)
    }
}
