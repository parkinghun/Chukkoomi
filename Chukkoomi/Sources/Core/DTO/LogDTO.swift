//
//  LogDTO.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import Foundation

// MARK: - Log Response
struct LogResponseDTO: Decodable {
    let count: Int
    let logs: [LogItemDTO]
}

// MARK: - Log Item
struct LogItemDTO: Decodable {
    let date: String
    let name: String
    let method: String
    let route_path: String
    let body: String
    let status_code: String
}

extension LogResponseDTO {
    var toDomain: LogResponse {
        return LogResponse(
            count: count,
            logs: logs.map { $0.toDomain }
        )
    }
}

extension LogItemDTO {
    var toDomain: LogItem {
        return LogItem(
            date: date,
            name: name,
            method: method,
            routePath: route_path,
            body: body,
            statusCode: status_code
        )
    }
}
