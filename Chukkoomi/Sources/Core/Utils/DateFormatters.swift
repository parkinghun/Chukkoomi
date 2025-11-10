//
//  DateFormatters.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/10/25.
//

import Foundation

enum DateFormatters {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
