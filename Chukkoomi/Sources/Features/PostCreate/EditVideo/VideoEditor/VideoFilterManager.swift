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
    case cool = "차가운"
    case animeGANHayao = "애니메이션"

    var displayName: String {
        return rawValue
    }
}

/// 비디오 필터 에러
enum VideoFilterError: Error, LocalizedError {
    case filterCreationFailed(String)
    case invalidImageExtent
    case modelNotAvailable
    case inputNameNotFound
    case pixelBufferCreationFailed
    case outputDataNotFound
    case mlProcessingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .filterCreationFailed(let filterName):
            return "필터 생성 실패: \(filterName)"
        case .invalidImageExtent:
            return "유효하지 않은 이미지 크기"
        case .modelNotAvailable:
            return "AI 모델을 사용할 수 없습니다"
        case .inputNameNotFound:
            return "모델 입력 이름을 찾을 수 없습니다"
        case .pixelBufferCreationFailed:
            return "이미지 버퍼 생성 실패"
        case .outputDataNotFound:
            return "모델 출력 데이터를 가져올 수 없습니다"
        case .mlProcessingFailed(let error):
            return "AI 처리 실패: \(error.localizedDescription)"
        }
    }
}

/// 비디오 필터 관리자
struct VideoFilterManager {
    
    /// 비디오에 필터를 적용한 AVVideoComposition 생성
    /// - Parameters:
    ///   - asset: 원본 비디오 AVAsset
    ///   - filter: 적용할 필터
    ///   - targetSize: 목표 크기 (nil이면 원본 크기 사용)
    /// - Returns: 필터가 적용된 AVVideoComposition (필터가 없으면 nil)
    static func createVideoComposition(
        for asset: AVAsset,
        filter: VideoFilter?,
        targetSize: CGSize? = nil,
        isPortraitFromPHAsset: Bool
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
        
        guard let naturalSize else {
            return nil
        }
        
        // naturalSize가 가로 방향인지 확인
        let isNaturalSizePortrait = naturalSize.width < naturalSize.height
        
        // 세로 영상인데 naturalSize가 가로로 나온 경우 swap
        let adjustedNaturalSize: CGSize
        if isPortraitFromPHAsset && !isNaturalSizePortrait {
            adjustedNaturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        } else {
            adjustedNaturalSize = naturalSize
        }
        
        // renderSize 계산
        let renderSize = targetSize ?? adjustedNaturalSize
        
        // AVVideoComposition 생성 (필터 + 리사이즈를 CIImage로 처리)
        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                var outputImage = request.sourceImage

                // 실제 extent 기준으로 방향 확인 (CIImage는 이미 회전된 extent를 가짐)
                let sourceExtent = outputImage.extent
                let isSourcePortrait = sourceExtent.width < sourceExtent.height
                let isRenderPortrait = renderSize.width < renderSize.height
                let actualNeedsRotation = isSourcePortrait != isRenderPortrait

                // 1. 필터 적용
                outputImage = applyFilter(filter, to: outputImage, originalImage: outputImage, targetSize: nil)

                // 2. 리사이징 및 회전 (extent 기준으로 판단)
                let actualScale: CGFloat
                let actualTransform: CGAffineTransform

                if actualNeedsRotation {
                    // 회전 필요: extent 기준으로 scale 계산
                    let scaleX = renderSize.width / sourceExtent.height
                    let scaleY = renderSize.height / sourceExtent.width
                    actualScale = min(scaleX, scaleY)
                    actualTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
                } else {
                    // 회전 불필요
                    let scaleX = renderSize.width / sourceExtent.width
                    let scaleY = renderSize.height / sourceExtent.height
                    actualScale = min(scaleX, scaleY)
                    actualTransform = .identity
                }

                let scaleTransform = CGAffineTransform(scaleX: actualScale, y: actualScale)
                let transformWithRotation = scaleTransform.concatenating(actualTransform)

                outputImage = outputImage.transformed(by: transformWithRotation)

                // 3. transform 후 extent 정규화 (음수 좌표를 원점으로)
                let transformedExtent = outputImage.extent

                if transformedExtent.origin.x != 0 || transformedExtent.origin.y != 0 {
                    let normalizeTransform = CGAffineTransform(
                        translationX: -transformedExtent.origin.x,
                        y: -transformedExtent.origin.y
                    )
                    outputImage = outputImage.transformed(by: normalizeTransform)
                }

                // 4. 중앙 정렬을 위한 offset 계산 (extent 기준)
                let scaledWidth = sourceExtent.width * actualScale
                let scaledHeight = sourceExtent.height * actualScale

                let actualOffsetX: CGFloat
                let actualOffsetY: CGFloat

                if actualNeedsRotation {
                    // 회전하는 경우: 90도 회전 후 중앙 정렬
                    actualOffsetX = (renderSize.width - scaledHeight) / 2
                    actualOffsetY = (renderSize.height - scaledWidth) / 2
                } else {
                    // 회전 불필요: 일반 중앙 정렬
                    actualOffsetX = (renderSize.width - scaledWidth) / 2
                    actualOffsetY = (renderSize.height - scaledHeight) / 2
                }

                let translateTransform = CGAffineTransform(translationX: actualOffsetX, y: actualOffsetY)
                outputImage = outputImage.transformed(by: translateTransform)

                // 5. 검정 배경 생성 (빈 공간을 채우기 위해)
                let background = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: renderSize))

                // 6. 이미지를 배경 위에 합성 (outputImage의 extent origin에 따라 위치 결정)
                let composited = outputImage.composited(over: background)

                // 7. renderSize 영역으로 crop
                let finalOutput = composited.cropped(to: CGRect(origin: .zero, size: renderSize))
                
                // GPU 가속 컨텍스트를 명시적으로 전달
                request.finish(with: finalOutput, context: Self.gpuContext)
            }
        )

        composition.renderSize = renderSize

        return composition
    }

    // MARK: - Filter Application Methods

    /// CIImage에 필터 적용
    /// - Parameters:
    ///   - filter: 적용할 필터
    ///   - image: 원본 이미지
    ///   - originalImage: ML 모델용 원본 이미지 (clamped되지 않은)
    ///   - targetSize: 목표 크기 (AnimeGAN 필터용, nil이면 원본 크기)
    /// - Returns: 필터가 적용된 이미지
    private static func applyFilter(_ filter: VideoFilter, to image: CIImage, originalImage: CIImage, targetSize: CGSize? = nil) -> CIImage {
        do {
            return try applyFilterThrowing(filter, to: image, originalImage: originalImage, targetSize: targetSize)
        } catch {
            // 에러 발생 시 원본 이미지 반환
            return image
        }
    }

    /// CIImage에 필터 적용 (throws)
    /// - Parameters:
    ///   - filter: 적용할 필터
    ///   - image: 원본 이미지
    ///   - originalImage: ML 모델용 원본 이미지 (clamped되지 않은)
    ///   - targetSize: 목표 크기 (AnimeGAN 필터용, nil이면 원본 크기)
    /// - Returns: 필터가 적용된 이미지
    /// - Throws: VideoFilterError
    static func applyFilterThrowing(_ filter: VideoFilter, to image: CIImage, originalImage: CIImage? = nil, targetSize: CGSize? = nil) throws -> CIImage {
        switch filter {
        case .blackAndWhite:
            return try applyBlackAndWhiteFilter(to: image)
        case .warm:
            return try applyWarmFilter(to: image)
        case .cool:
            return try applyCoolFilter(to: image)
        case .animeGANHayao:
            return try applyAnimeGANHayao(to: originalImage ?? image, targetSize: targetSize)
        }
    }

    /// 흑백 필터 적용
    private static func applyBlackAndWhiteFilter(to image: CIImage) throws -> CIImage {
        guard let filter = CIFilter(name: "CIPhotoEffectMono") else {
            throw VideoFilterError.filterCreationFailed("CIPhotoEffectMono")
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        guard let outputImage = filter.outputImage else {
            throw VideoFilterError.outputDataNotFound
        }
        return outputImage
    }

    /// 따뜻한 필터 적용
    private static func applyWarmFilter(to image: CIImage) throws -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else {
            throw VideoFilterError.filterCreationFailed("CITemperatureAndTint")
        }

        // 색온도를 높여서 따뜻한 느낌 (오렌지/노란 톤)
        let warmVector = CIVector(x: 8000, y: 0)
        let neutralVector = CIVector(x: 6500, y: 0)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(warmVector, forKey: "inputNeutral")
        filter.setValue(neutralVector, forKey: "inputTargetNeutral")

        guard let outputImage = filter.outputImage else {
            throw VideoFilterError.outputDataNotFound
        }
        return outputImage
    }

    /// 차가운 필터 적용
    private static func applyCoolFilter(to image: CIImage) throws -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else {
            throw VideoFilterError.filterCreationFailed("CITemperatureAndTint")
        }

        // 색온도를 낮춰서 차가운 느낌 (파란 톤)
        let coolVector = CIVector(x: 5000, y: 0)
        let neutralVector = CIVector(x: 6500, y: 0)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(coolVector, forKey: "inputNeutral")
        filter.setValue(neutralVector, forKey: "inputTargetNeutral")

        guard let outputImage = filter.outputImage else {
            throw VideoFilterError.outputDataNotFound
        }
        return outputImage
    }

    /// AnimeGANv3 CoreML 필터 적용
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - targetSize: 목표 크기 (nil이면 원본 크기)
    /// - Returns: 필터가 적용된 이미지
    /// - Throws: VideoFilterError
    private static func applyAnimeGANHayao(to image: CIImage, targetSize: CGSize? = nil) throws -> CIImage {
        // extent 유효성 검사
        guard image.extent.width > 0 && image.extent.height > 0,
              image.extent.width.isFinite && image.extent.height.isFinite else {
            throw VideoFilterError.invalidImageExtent
        }

        // 캐싱된 모델 사용
        guard let mlModel = animeGANModel else {
            throw VideoFilterError.modelNotAvailable
        }

        do {
            // 모델 입력 이름 가져오기
            guard let inputName = mlModel.modelDescription.inputDescriptionsByName.keys.first else {
                throw VideoFilterError.inputNameNotFound
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
                throw VideoFilterError.pixelBufferCreationFailed
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
                    throw VideoFilterError.pixelBufferCreationFailed
                }
                outputImage = CIImage(cvPixelBuffer: pixelBuffer)
            } else {
                throw VideoFilterError.outputDataNotFound
            }

            // 목표 크기로 리사이징
            let scaleBackX = finalSize.width / outputImage.extent.width
            let scaleBackY = finalSize.height / outputImage.extent.height
            outputImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleBackX, y: scaleBackY))

            return outputImage
        } catch let error as VideoFilterError {
            throw error
        } catch {
            throw VideoFilterError.mlProcessingFailed(error)
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
            return nil
        }

        do {
            // GPU 사용 설정
            let config = MLModelConfiguration()
            config.computeUnits = .all  // CPU, GPU, Neural Engine 모두 사용

            return try MLModel(contentsOf: modelURL, configuration: config)
        } catch {
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
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
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
