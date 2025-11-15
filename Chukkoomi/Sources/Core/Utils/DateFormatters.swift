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

    // MARK: - 채팅방 리스트 날짜 포맷팅
    /// 채팅방 리스트에서 사용하는 날짜 포맷
    /// - 오늘: "오전 HH:MM" 또는 "오후 HH:MM"
    /// - 어제: "어제"
    /// - 그 이전: "MM월 DD일"
    static func formatChatListDate(_ dateString: String) -> String {
        guard let date = parseDate(dateString) else {
            return ""
        }

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let messageStart = calendar.startOfDay(for: date)

        let daysDifference = calendar.dateComponents([.day], from: messageStart, to: todayStart).day ?? 0

        if daysDifference == 0 {
            // 오늘: "오전 HH:MM" 형식
            let components = calendar.dateComponents([.hour, .minute], from: date)
            guard let hour = components.hour, let minute = components.minute else {
                return ""
            }

            let period = hour < 12 ? "오전" : "오후"
            let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)

            return String(format: "%@ %d:%02d", period, displayHour, minute)
        } else if daysDifference == 1 {
            // 어제
            return "어제"
        } else {
            // 그 이전: "MM월 DD일"
            let components = calendar.dateComponents([.month, .day], from: date)
            guard let month = components.month, let day = components.day else {
                return ""
            }
            return "\(month)월 \(day)일"
        }
    }

    // MARK: - 채팅 메시지 시간 포맷팅
    /// 채팅 메시지에서 사용하는 시간 포맷
    /// "오전 HH:MM" 또는 "오후 HH:MM" 형식
    static func formatChatMessageTime(_ dateString: String) -> String {
        guard let date = parseDate(dateString) else {
            return ""
        }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return ""
        }

        let period = hour < 12 ? "오전" : "오후"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)

        return String(format: "%@ %d:%02d", period, displayHour, minute)
    }

    // MARK: - 채팅 날짜 구분선 포맷팅
    /// 채팅 화면에서 사용하는 날짜 구분선 포맷
    /// "YYYY년 MM월 DD일 (요일)" 형식
    static func formatChatDateSeparator(_ dateString: String) -> String {
        guard let date = parseDate(dateString) else {
            return ""
        }

        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)

        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let weekday = components.weekday else {
            return ""
        }

        let weekdayString = weekdays[weekday]

        return "\(year)년 \(month)월 \(day)일 (\(weekdayString))"
    }

    // MARK: - 날짜가 다른지 확인
    /// 두 날짜 문자열이 다른 날인지 확인
    static func isDifferentDay(_ date1: String, _ date2: String) -> Bool {
        guard let d1 = parseDate(date1), let d2 = parseDate(date2) else {
            return false
        }

        let start1 = calendar.startOfDay(for: d1)
        let start2 = calendar.startOfDay(for: d2)

        return start1 != start2
    }

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
