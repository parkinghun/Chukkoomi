//
//  DateFormatters.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/10/25.
//

import Foundation

enum DateFormatters {
    // MARK: - ISO8601 Formatter
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - ISO8601 Formatter (without fractional seconds)
    static let iso8601WithoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - 유연한 Date 파싱
    /// API에서 받은 date 문자열을 여러 형식으로 시도하여 파싱
    static func parseDate(_ dateString: String) -> Date? {
        // 1. ISO8601 with fractional seconds
        if let date = iso8601.date(from: dateString) {
            return date
        }

        // 2. ISO8601 without fractional seconds
        if let date = iso8601WithoutFractional.date(from: dateString) {
            return date
        }

        // 3. DateFormatter로 다양한 형식 시도
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",           // 2023-12-02T05:00:00+0000
            "yyyy-MM-dd'T'HH:mm:ssXXX",         // 2023-12-02T05:00:00+00:00
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",       // 2023-12-02T05:00:00.000+0000
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",     // 2023-12-02T05:00:00.000+00:00
            "yyyy-MM-dd'T'HH:mm:ss",            // 2023-12-02T05:00:00
            "yyyy-MM-dd HH:mm:ss"               // 2023-12-02 05:00:00
        ]

        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    // MARK: - Calendar (재사용)
    private static let calendar = Calendar.current

    // MARK: - 요일 배열 (재사용)
    private static let weekdays = ["", "일", "월", "화", "수", "목", "금", "토"]

    // MARK: - 경기 날짜 포맷팅
    /// "11월 11일 (화) 오후 2시" 형식으로 포맷
    static func formatMatchDate(_ date: Date) -> String {
        let components = calendar.dateComponents([.month, .day, .weekday, .hour, .minute], from: date)

        guard let month = components.month,
              let day = components.day,
              let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else {
            return ""
        }

        // 요일
        let weekdayString = weekdays[weekday]

        // 오전/오후 및 시간
        let (period, displayHour): (String, Int)
        if hour < 12 {
            period = "오전"
            displayHour = hour == 0 ? 12 : hour
        } else {
            period = "오후"
            displayHour = hour == 12 ? 12 : hour - 12
        }

        // 시간 문자열
        let timeString: String
        if minute == 0 {
            timeString = "\(period) \(displayHour)시"
        } else {
            timeString = String(format: "%@ %d시 %02d분", period, displayHour, minute)
        }

        return "\(month)월 \(day)일 (\(weekdayString)) \(timeString)"
    }
}

// MARK: - Date Extension (편의 메서드)
extension Date {
    /// "11월 11일 (화) 오후 2시" 형식으로 포맷
    var matchDateString: String {
        DateFormatters.formatMatchDate(self)
    }
}
