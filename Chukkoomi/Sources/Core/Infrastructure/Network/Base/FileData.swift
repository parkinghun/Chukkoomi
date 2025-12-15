//
//  FileData.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import Foundation

/// 파일 업로드를 위한 데이터 구조체
struct FileData {
    let data: Data
    let fileName: String
    let mimeType: String

    /// Data로부터 자동으로 MIME 타입과 파일 이름을 생성
    init(data: Data, customFileName: String? = nil) {
        self.data = data
        let detectedType = Self.detectMimeType(from: data)
        self.mimeType = detectedType.mimeType
        self.fileName = customFileName ?? "\(UUID().uuidString).\(detectedType.fileExtension)"
    }

    /// 명시적으로 모든 정보를 제공
    init(data: Data, fileName: String, mimeType: String) {
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }

    // MARK: - MIME Type Detection

    /// Magic Number를 사용한 MIME 타입 감지
    private static func detectMimeType(from data: Data) -> (mimeType: String, fileExtension: String) {
        guard data.count >= 12 else {
            return ("application/octet-stream", "bin")
        }

        let bytes = [UInt8](data.prefix(12))

        // JPEG
        if bytes.count >= 3,
           bytes[0] == 0xFF,
           bytes[1] == 0xD8,
           bytes[2] == 0xFF {
            return ("image/jpeg", "jpg")
        }

        // PNG
        if bytes.count >= 8,
           bytes[0] == 0x89,
           bytes[1] == 0x50,
           bytes[2] == 0x4E,
           bytes[3] == 0x47,
           bytes[4] == 0x0D,
           bytes[5] == 0x0A,
           bytes[6] == 0x1A,
           bytes[7] == 0x0A {
            return ("image/png", "png")
        }

        // GIF
        if bytes.count >= 6,
           bytes[0] == 0x47,
           bytes[1] == 0x49,
           bytes[2] == 0x46,
           bytes[3] == 0x38,
           (bytes[4] == 0x37 || bytes[4] == 0x39),
           bytes[5] == 0x61 {
            return ("image/gif", "gif")
        }

        // WebP
        if bytes.count >= 12,
           bytes[0] == 0x52,
           bytes[1] == 0x49,
           bytes[2] == 0x46,
           bytes[3] == 0x46,
           bytes[8] == 0x57,
           bytes[9] == 0x45,
           bytes[10] == 0x42,
           bytes[11] == 0x50 {
            return ("image/webp", "webp")
        }

        // MP4 (Video)
        if bytes.count >= 12,
           bytes[4] == 0x66,
           bytes[5] == 0x74,
           bytes[6] == 0x79,
           bytes[7] == 0x70 {
            return ("video/mp4", "mp4")
        }

        // MOV (QuickTime)
        if bytes.count >= 8,
           bytes[4] == 0x66,
           bytes[5] == 0x74,
           bytes[6] == 0x79,
           bytes[7] == 0x70 {
            return ("video/quicktime", "mov")
        }

        // PDF
        if bytes.count >= 5,
           bytes[0] == 0x25,
           bytes[1] == 0x50,
           bytes[2] == 0x44,
           bytes[3] == 0x46,
           bytes[4] == 0x2D {
            return ("application/pdf", "pdf")
        }

        // Default
        return ("application/octet-stream", "bin")
    }
}

// MARK: - File Upload Error

enum FileUploadError: LocalizedError {
    case fileTooLarge(size: Int, maxSize: Int)
    case tooManyFiles(count: Int, maxCount: Int)
    case emptyFile
    case invalidFileData

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let size, let maxSize):
            let sizeMB = Double(size) / 1024.0 / 1024.0
            let maxSizeMB = Double(maxSize) / 1024.0 / 1024.0
            return "파일 크기가 너무 큽니다. (현재: \(String(format: "%.2f", sizeMB))MB, 최대: \(String(format: "%.2f", maxSizeMB))MB)"

        case .tooManyFiles(let count, let maxCount):
            return "파일 개수가 너무 많습니다. (현재: \(count)개, 최대: \(maxCount)개)"

        case .emptyFile:
            return "빈 파일은 업로드할 수 없습니다."

        case .invalidFileData:
            return "유효하지 않은 파일 데이터입니다."
        }
    }
}
