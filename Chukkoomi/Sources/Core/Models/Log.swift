//
//  Log.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import Foundation

// MARK: - Log Response
struct LogResponse: Equatable {
    let count: Int
    let logs: [LogItem]
}

// MARK: - Log Item
struct LogItem: Equatable {
    let date: String
    let name: String
    let method: String
    let routePath: String
    let body: String
    let statusCode: String
}

extension LogResponse {
    var toDTO: LogResponseDTO {
        return LogResponseDTO(
            count: count,
            logs: logs.map { $0.toDTO }
        )
    }
}

extension LogItem {
    var toDTO: LogItemDTO {
        return LogItemDTO(
            date: date,
            name: name,
            method: method,
            route_path: routePath,
            body: body,
            status_code: statusCode
        )
    }
}
