//
//  KeychainManager.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import Foundation
import Security

final class KeychainManager {

    static let shared = KeychainManager()

    private init() {}

    // MARK: - Keys
    enum Key: String {
        case accessToken
        case refreshToken
    }

    // MARK: - Save
    @discardableResult
    func save(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        // 기존 값 삭제
        delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Load
    func load(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    // MARK: - Delete
    @discardableResult
    func delete(for key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }

    // MARK: - Delete All
    @discardableResult
    func deleteAll() -> Bool {
        let accessTokenDeleted = delete(for: .accessToken)
        let refreshTokenDeleted = delete(for: .refreshToken)
        return accessTokenDeleted && refreshTokenDeleted
    }
}
