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
    var bodyEncoder: BodyEncoder { get }
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
        if let body {
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

    init<T: Encodable>(_ value: T) {
        self._encode = value.encode
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
            // TODO: Token 저장하면 수정하기
            return ("Authorization", APIInfo.token)
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
        let mirror = Mirror(reflecting: parameters)
        
        for child in mirror.children {
            guard let key = child.label else { continue }
            let value = child.value
            
            if let files = value as? [MultipartFile] {
                for file in files {
                    body.append(convertFileData(fieldName: key,
                                                fileName: file.fileName,
                                                mimeType: file.mimeType,
                                                fileData: file.data))
                }
            } else if let file = value as? MultipartFile {
                body.append(convertFileData(fieldName: key,
                                            fileName: file.fileName,
                                            mimeType: file.mimeType,
                                            fileData: file.data))
            } else {
                body.append(convertFormField(named: key, value: "\(value)"))
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
