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

    private let taskStorage = TaskStorage()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        let queue = OperationQueue()
        queue.qualityOfService = .utility
        return URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }()
}

// MARK: - Request Methods
extension NetworkManager {

    /// HTTP Method와 BodyEncoder에 따라 분기하는 통합 메서드 (토큰 만료 인터셉트 포함)
    func performRequest<T: Decodable>(_ router: Router, as type: T.Type, progress: ((Double) -> Void)? = nil) async throws -> T {
        do {
            return try await performRequestWithoutInterception(router, as: type, progress: progress)
        } catch NetworkError.statusCode(419, _) {
            // 419 에러 (AccessToken 만료) -> 토큰 갱신 시도
            let refreshSuccess = await TokenRefreshManager.shared.refreshTokenIfNeeded()

            guard refreshSuccess else {
                throw NetworkError.unauthorized
            }

            // 토큰 갱신 성공 -> 원래 요청 재시도
            return try await performRequestWithoutInterception(router, as: type, progress: progress)
        } catch NetworkError.statusCode(418, _) {
            // 418 에러 (RefreshToken 만료) -> 자동 로그아웃
            await TokenRefreshManager.shared.handleTokenExpiration()
            throw NetworkError.refreshTokenExpired
        }
    }

    /// 빈 응답을 반환하는 요청 (삭제 등에 사용)
    func performRequestWithoutResponse(_ router: Router) async throws {
        do {
            try await performRequestWithoutResponseAndInterception(router)
        } catch NetworkError.statusCode(419, _) {
            // 419 에러 (AccessToken 만료) -> 토큰 갱신 시도
            let refreshSuccess = await TokenRefreshManager.shared.refreshTokenIfNeeded()

            guard refreshSuccess else {
                throw NetworkError.unauthorized
            }

            // 토큰 갱신 성공 -> 원래 요청 재시도
            try await performRequestWithoutResponseAndInterception(router)
        } catch NetworkError.statusCode(418, _) {
            // 418 에러 (RefreshToken 만료) -> 자동 로그아웃
            await TokenRefreshManager.shared.handleTokenExpiration()
            throw NetworkError.refreshTokenExpired
        }
    }

    /// 빈 응답 요청 (인터셉트 없음)
    private func performRequestWithoutResponseAndInterception(_ router: Router) async throws {
        _ = try await basicRequest(router)
    }

    /// HTTP Method와 BodyEncoder에 따라 분기하는 내부 메서드 (인터셉트 없음)
    private func performRequestWithoutInterception<T: Decodable>(_ router: Router, as type: T.Type, progress: ((Double) -> Void)? = nil) async throws -> T {
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
            // 에러 응답의 body에서 message 파싱 시도
            let errorMessage = try? JSONDecoder().decode(BasicMessageResponseDTO.self, from: data).message
            throw NetworkError.statusCode(httpResponse.statusCode, message: errorMessage)
        }

        return data
    }

    // 파일 업로드 요청 - Data 반환 (progress tracking 지원)
    private func upload(_ router: Router, progress: ((Double) -> Void)? = nil) async throws -> Data {
        var urlRequest = try router.asURLRequest()

        guard let bodyData = urlRequest.httpBody else {
            throw NetworkError.noData
        }

        // uploadTask는 URLRequest에 httpBody가 있으면 안 되므로 제거
        urlRequest.httpBody = nil
        let task = session.uploadTask(with: urlRequest, from: bodyData)
        let taskIdentifier = task.taskIdentifier

        // Progress handler 저장
        if let progress {
            await taskStorage.setProgressHandler(progress, for: taskIdentifier)
        }

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await taskStorage.setContinuation(continuation, for: taskIdentifier)
                task.resume()
            }
        }
    }

    // 파일 다운로드 요청 - Data 반환 (progress tracking 지원)
    func download(_ router: Router, progress: ((Double) -> Void)? = nil) async throws -> Data {
        let urlRequest = try router.asURLRequest()
        let task = session.downloadTask(with: urlRequest)
        let taskIdentifier = task.taskIdentifier

        // Progress handler 저장
        if let progress {
            await taskStorage.setProgressHandler(progress, for: taskIdentifier)
        }

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await taskStorage.setDownloadContinuation(continuation, for: taskIdentifier)
                task.resume()
            }
        }
    }

    /// 전체 진행률 핸들러 설정
    func setTotalProgressHandler(_ handler: @escaping (Double) -> Void) {
        // 메인 스레드에서 호출되도록 래핑
        Task {
            await taskStorage.setProgressHandler({ progress in
                Task { @MainActor in
                    handler(progress)
                }
            }, for: -1)
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
        Task {
            if let handler = await taskStorage.getProgressHandler(for: taskIdentifier) {
                Task { @MainActor in
                    handler(progress)
                }
            }
        }
    }

    // Task 완료 처리
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskIdentifier = task.taskIdentifier

        Task {
            guard let continuation = await taskStorage.getContinuation(for: taskIdentifier) else { return }

            defer {
                // 정리
                Task {
                    await taskStorage.removeContinuation(for: taskIdentifier)
                    await taskStorage.removeProgressHandler(for: taskIdentifier)
                    await taskStorage.removeData(for: taskIdentifier)
                }
            }

            if let error = error {
                continuation.resume(throwing: error)
                return
            }

            // HTTP 응답 상태 코드 확인
            if let httpResponse = task.response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    // 에러 응답의 body에서 message 파싱 시도
                    let errorMessage: String?
                    if let data = await taskStorage.getData(for: taskIdentifier) {
                        errorMessage = try? JSONDecoder().decode(BasicMessageResponseDTO.self, from: data).message
                    } else {
                        errorMessage = nil
                    }
                    continuation.resume(throwing: NetworkError.statusCode(httpResponse.statusCode, message: errorMessage))
                    return
                }
            }

            // 데이터 반환
            if let data = await taskStorage.getData(for: taskIdentifier) {
                continuation.resume(returning: data)
            } else {
                continuation.resume(throwing: NetworkError.noData)
            }
        }
    }
}

// MARK: - URLSessionDataDelegate
extension NetworkManager: URLSessionDataDelegate {

    // 데이터 수신
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskIdentifier = dataTask.taskIdentifier

        Task {
            await taskStorage.appendData(data, for: taskIdentifier)
        }
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
        Task {
            if let handler = await taskStorage.getProgressHandler(for: taskIdentifier) {
                Task { @MainActor in
                    handler(progress)
                }
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

        Task {
            guard let continuation = await taskStorage.getDownloadContinuation(for: taskIdentifier) else { return }

            defer {
                // 정리
                Task {
                    await taskStorage.removeDownloadContinuation(for: taskIdentifier)
                    await taskStorage.removeProgressHandler(for: taskIdentifier)
                }
            }

            // HTTP 응답 상태 코드 확인
            if let httpResponse = downloadTask.response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    // 에러 응답의 body에서 message 파싱 시도 (다운로드 파일에서)
                    let errorMessage: String?
                    do {
                        let data = try Data(contentsOf: location)
                        errorMessage = try? JSONDecoder().decode(BasicMessageResponseDTO.self, from: data).message
                    } catch {
                        errorMessage = nil
                    }
                    continuation.resume(throwing: NetworkError.statusCode(httpResponse.statusCode, message: errorMessage))
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
}

// MARK: - Task Storage Actor (Thread-safe dictionary access)
actor TaskStorage {
    private var progressHandlers: [Int: (Double) -> Void] = [:]
    private var continuations: [Int: CheckedContinuation<Data, Error>] = [:]
    private var downloadContinuations: [Int: CheckedContinuation<Data, Error>] = [:]
    private var receivedData: [Int: Data] = [:]

    // Progress Handler
    func setProgressHandler(_ handler: @escaping (Double) -> Void, for taskId: Int) {
        progressHandlers[taskId] = handler
    }

    func getProgressHandler(for taskId: Int) -> ((Double) -> Void)? {
        return progressHandlers[taskId]
    }

    func removeProgressHandler(for taskId: Int) {
        progressHandlers.removeValue(forKey: taskId)
    }

    // Upload Continuation
    func setContinuation(_ continuation: CheckedContinuation<Data, Error>, for taskId: Int) {
        continuations[taskId] = continuation
    }

    func getContinuation(for taskId: Int) -> CheckedContinuation<Data, Error>? {
        return continuations[taskId]
    }

    func removeContinuation(for taskId: Int) {
        continuations.removeValue(forKey: taskId)
    }

    // Download Continuation
    func setDownloadContinuation(_ continuation: CheckedContinuation<Data, Error>, for taskId: Int) {
        downloadContinuations[taskId] = continuation
    }

    func getDownloadContinuation(for taskId: Int) -> CheckedContinuation<Data, Error>? {
        return downloadContinuations[taskId]
    }

    func removeDownloadContinuation(for taskId: Int) {
        downloadContinuations.removeValue(forKey: taskId)
    }

    // Received Data
    func appendData(_ data: Data, for taskId: Int) {
        if receivedData[taskId] == nil {
            receivedData[taskId] = Data()
        }
        receivedData[taskId]?.append(data)
    }

    func getData(for taskId: Int) -> Data? {
        return receivedData[taskId]
    }

    func removeData(for taskId: Int) {
        receivedData.removeValue(forKey: taskId)
    }
}
