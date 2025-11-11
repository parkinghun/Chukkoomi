//
//  Router.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

import Foundation

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Router Protocol
protocol Router {

    var version: String { get }
    var path: String { get }
    var method: HTTPMethod { get }

    var headers: [HTTPHeader]? { get }
    var body: AnyEncodable? { get }
    var bodyEncoder: BodyEncoder? { get }
    var query: [HTTPQuery]? { get }

    func asURLRequest() throws -> URLRequest
}

extension Router {
    var baseURL: String {
        APIInfo.baseURL
    }
    
    func asURLRequest() throws -> URLRequest {
        // URL 검증
        guard var url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }

        // Query
        if let query {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = query.map { URLQueryItem(name: $0.tuple.key, value: $0.tuple.value) }
            components?.queryItems = queryItems
            url = components?.url ?? url
        }

        // Request 생성
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Header
        headers?.forEach { request.setValue($0.tuple.value, forHTTPHeaderField: $0.tuple.key) }

        // Body
        if let body, let bodyEncoder {
            switch bodyEncoder {
            case .json:
                try JSONParameterEncoder().encode(body, into: &request)
            case .multipart:
                try MultipartFormDataEncoder().encode(body, into: &request)
            }
        }

        return request
    }
}

// MARK: - AnyEncodable
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    fileprivate let base: Any  // MultipartFormDataEncoder가 원본 값에 접근하기 위해 사용

    init<T: Encodable>(_ value: T) {
        self._encode = value.encode
        self.base = value
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - BodyEncoder
enum BodyEncoder {
    case json
    case multipart
}

// MARK: - HTTPHeader
enum HTTPHeader {
    case apiKey
    case authorization
    case productId
    case custom(key: String, value: String)

    var tuple: (key: String, value: String) {
        switch self {
        case .apiKey:
            return ("SeSACKey", APIInfo.apiKey)
        case .authorization:
            let token = KeychainManager.shared.load(for: .accessToken) ?? ""
            return ("Authorization", token)
        case .productId:
            return ("ProductId", APIInfo.productId)
        case .custom(let key, let value):
            return (key, value)
        }
    }
    
    static var basic: [Self] {
        return [
            .apiKey,
            .authorization,
            .productId
        ]
    }
}

// MARK: - HTTPQuery
enum HTTPQuery {
    case next(String)
    case limit(Int)
    case category([String])
    case custom(key: String, value: String)

    var tuple: (key: String, value: String) {
        switch self {
        case .next(let next):
            return ("next", next)
        case .limit(let num):
            return ("limit", "\(num)")
        case .category(let category):
            return ("category", category.joined(separator: ","))
        case .custom(let key, let value):
            return (key, value)
        }
    }
}

// MARK: - ParameterEncoder 프로토콜
private protocol ParameterEncoder {
    func encode<T: Encodable>(_ parameters: T, into request: inout URLRequest) throws
}

// MARK: - JSON 인코딩
struct JSONParameterEncoder: ParameterEncoder {
    func encode<T>(_ parameters: T, into request: inout URLRequest) throws where T : Encodable {
        request.httpBody = try JSONEncoder().encode(parameters)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
}

// MARK: - Multipart/Form-Data 인코딩
private struct MultipartFormDataEncoder: ParameterEncoder {
    let boundary = "Boundary-\(UUID().uuidString)"
    
    func encode<T>(_ parameters: T, into request: inout URLRequest) throws where T : Encodable {
        var body = Data()

        // AnyEncodable에서 원본 값 추출
        let actualValue: Any
        if let anyEncodable = parameters as? AnyEncodable {
            actualValue = anyEncodable.base
        } else {
            actualValue = parameters
        }

        let mirror = Mirror(reflecting: actualValue)

        for child in mirror.children {
            guard let key = child.label else { continue }
            let value = child.value

            // Optional unwrapping
            let unwrappedValue: Any
            let valueMirror = Mirror(reflecting: value)
            if valueMirror.displayStyle == .optional {
                // Optional인 경우
                if let wrappedValue = valueMirror.children.first?.value {
                    unwrappedValue = wrappedValue
                } else {
                    // nil이면 필드를 보내지 않음
                    continue
                }
            } else {
                unwrappedValue = value
            }

            // 타입별 처리
            if let files = unwrappedValue as? [MultipartFile] {
                for file in files {
                    body.append(convertFileData(fieldName: key,
                                                fileName: file.fileName,
                                                mimeType: file.mimeType,
                                                fileData: file.data))
                }
            } else if let file = unwrappedValue as? MultipartFile {
                body.append(convertFileData(fieldName: key,
                                            fileName: file.fileName,
                                            mimeType: file.mimeType,
                                            fileData: file.data))
            } else {
                body.append(convertFormField(named: key, value: "\(unwrappedValue)"))
            }
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    }
    
    // 일반 텍스트 필드 변환
    func convertFormField(named name: String, value: String) -> Data {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        fieldString += "\(value)\r\n"
        return Data(fieldString.utf8)
    }
    
    // 파일 데이터 변환
    func convertFileData(fieldName: String, fileName: String, mimeType: String, fileData: Data) -> Data {
        var fieldData = Data()
        fieldData.append("--\(boundary)\r\n".data(using: .utf8)!)
        fieldData.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        fieldData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        fieldData.append(fileData)
        fieldData.append("\r\n".data(using: .utf8)!)
        return fieldData
    }
}

// MARK: - MultipartFile
struct MultipartFile {
    let data: Data
    let fileName: String
    let mimeType: String
}
