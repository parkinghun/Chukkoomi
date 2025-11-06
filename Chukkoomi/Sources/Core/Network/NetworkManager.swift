//
//  NetworkManager.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

import Foundation

final class NetworkManager: NSObject {
    static let shared = NetworkManager()
    private override init() {}

    // 요청별 진행률 핸들러
    private var progressHandlers: [Int: (Double) -> Void] = [:]
    // Continuation 저장 (Upload용)
    private var continuations: [Int: CheckedContinuation<Data, Error>] = [:]
    // Continuation 저장 (Download용)
    private var downloadContinuations: [Int: CheckedContinuation<Data, Error>] = [:]
    // 받은 데이터 저장
    private var receivedData: [Int: Data] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        let queue = OperationQueue()
        queue.qualityOfService = .utility
        return URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }()
}

// MARK: - Request Methods
extension NetworkManager {

    /// HTTP Method와 BodyEncoder에 따라 분기하는 통합 메서드
    func performRequest<T: Decodable>(_ router: Router, as type: T.Type, progress: ((Double) -> Void)? = nil) async throws -> T {
        let data: Data

        switch router.method {
        case .post, .put, .patch:
            // Multipart 인코더면 업로드, 아니면 일반 요청
            if router.bodyEncoder == .multipart {
                data = try await upload(router, progress: progress)
            } else {
                data = try await basicRequest(router)
            }
        case .get, .delete:
            data = try await basicRequest(router)
        }

        // 디코딩 (백그라운드에서 수행)
        let decoded: T
        do {
            decoded = try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }

        // 메인 스레드로 전환하여 반환
        return await MainActor.run {
            decoded
        }
    }

    // 일반 네트워크 요청 (진행률 파악이 필요 없는 작업)
    private func basicRequest(_ router: Router) async throws -> Data {
        let urlRequest = try router.asURLRequest()
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.statusCode(httpResponse.statusCode)
        }

        return data
    }

    // 파일 업로드 요청 - Data 반환 (progress tracking 지원)
    private func upload(_ router: Router, progress: ((Double) -> Void)? = nil) async throws -> Data {
        let urlRequest = try router.asURLRequest()

        guard let bodyData = urlRequest.httpBody else {
            throw NetworkError.noData
        }

        let task = session.uploadTask(with: urlRequest, from: bodyData)
        let taskIdentifier = task.taskIdentifier

        // Progress handler 저장
        if let progress {
            progressHandlers[taskIdentifier] = progress
        }

        return try await withCheckedThrowingContinuation { continuation in
            continuations[taskIdentifier] = continuation
            task.resume()
        }
    }

    // 파일 다운로드 요청 - Data 반환 (progress tracking 지원)
    func download(_ router: Router, progress: ((Double) -> Void)? = nil) async throws -> Data {
        let urlRequest = try router.asURLRequest()
        let task = session.downloadTask(with: urlRequest)
        let taskIdentifier = task.taskIdentifier

        // Progress handler 저장
        if let progress {
            progressHandlers[taskIdentifier] = progress
        }

        return try await withCheckedThrowingContinuation { continuation in
            downloadContinuations[taskIdentifier] = continuation
            task.resume()
        }
    }

    /// 전체 진행률 핸들러 설정
    func setTotalProgressHandler(_ handler: @escaping (Double) -> Void) {
        // 메인 스레드에서 호출되도록 래핑
        progressHandlers[-1] = { progress in
            Task { @MainActor in
                handler(progress)
            }
        }
    }
}

// MARK: - URLSessionTaskDelegate
extension NetworkManager: URLSessionTaskDelegate {

    // Upload 진행률 추적
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let taskIdentifier = task.taskIdentifier

        // 개별 진행률 핸들러 호출 (메인 스레드)
        if let handler = progressHandlers[taskIdentifier] {
            Task { @MainActor in
                handler(progress)
            }
        }
    }

    // Task 완료 처리
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskIdentifier = task.taskIdentifier

        defer {
            // 정리
            continuations.removeValue(forKey: taskIdentifier)
            progressHandlers.removeValue(forKey: taskIdentifier)
            receivedData.removeValue(forKey: taskIdentifier)
        }

        guard let continuation = continuations[taskIdentifier] else { return }

        if let error = error {
            continuation.resume(throwing: error)
            return
        }

        // HTTP 응답 상태 코드 확인
        if let httpResponse = task.response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                continuation.resume(throwing: NetworkError.statusCode(httpResponse.statusCode))
                return
            }
        }

        // 데이터 반환
        if let data = receivedData[taskIdentifier] {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: NetworkError.noData)
        }
    }
}

// MARK: - URLSessionDataDelegate
extension NetworkManager: URLSessionDataDelegate {

    // 데이터 수신
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskIdentifier = dataTask.taskIdentifier

        if receivedData[taskIdentifier] == nil {
            receivedData[taskIdentifier] = Data()
        }

        receivedData[taskIdentifier]?.append(data)
    }
}

// MARK: - URLSessionDownloadDelegate
extension NetworkManager: URLSessionDownloadDelegate {

    // 다운로드 진행률 추적
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let taskIdentifier = downloadTask.taskIdentifier

        // 개별 진행률 핸들러 호출 (메인 스레드)
        if let handler = progressHandlers[taskIdentifier] {
            Task { @MainActor in
                handler(progress)
            }
        }
    }

    // 다운로드 완료 처리
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskIdentifier = downloadTask.taskIdentifier

        defer {
            // 정리
            downloadContinuations.removeValue(forKey: taskIdentifier)
            progressHandlers.removeValue(forKey: taskIdentifier)
        }

        guard let continuation = downloadContinuations[taskIdentifier] else { return }

        // HTTP 응답 상태 코드 확인
        if let httpResponse = downloadTask.response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                continuation.resume(throwing: NetworkError.statusCode(httpResponse.statusCode))
                return
            }
        }

        // 임시 파일에서 Data 읽기
        do {
            let data = try Data(contentsOf: location)
            continuation.resume(returning: data)
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

// MARK: - NetworkError
enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case statusCode(Int)
    case noData
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "유효하지 않은 응답입니다."
        case .statusCode(let code):
            return "HTTP 상태 코드 에러: \(code)"
        case .noData:
            return "데이터가 없습니다."
        case .decodingFailed(let error):
            return "디코딩에 실패했습니다: \(error.localizedDescription)"
        }
    }
}
