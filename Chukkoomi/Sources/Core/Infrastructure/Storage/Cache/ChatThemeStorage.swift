//
//  ChatThemeStorage.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/22/25.
//

import Foundation

struct ChatThemeStorage {
    private static let userDefaults = UserDefaults.standard
    private static let themeKeyPrefix = "chatTheme_"

    /// 특정 채팅방의 테마를 저장
    static func saveTheme(_ theme: ChatFeature.ChatTheme, for roomId: String) {
        let key = themeKeyPrefix + roomId
        userDefaults.set(theme.rawValue, forKey: key)
    }

    /// 특정 채팅방의 테마를 불러오기 (저장된 값이 없으면 기본 테마 반환)
    static func loadTheme(for roomId: String) -> ChatFeature.ChatTheme {
        let key = themeKeyPrefix + roomId
        guard let rawValue = userDefaults.string(forKey: key),
              let theme = ChatFeature.ChatTheme(rawValue: rawValue) else {
            return .default
        }
        return theme
    }

    /// 특정 채팅방의 테마를 삭제
    static func removeTheme(for roomId: String) {
        let key = themeKeyPrefix + roomId
        userDefaults.removeObject(forKey: key)
    }
}
