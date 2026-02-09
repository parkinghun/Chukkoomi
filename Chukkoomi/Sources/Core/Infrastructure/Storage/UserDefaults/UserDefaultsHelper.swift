//
//  UserDefaultsHelper.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/14/25.
//

import Foundation

enum UserDefaultsHelper {
    
    @UserDefaultsItem(key: "UserId", type: String.self)
    static var userId: String?

#if DEBUG
    /// 테스트용 로그인 우회 플래그
    @UserDefaultsItem(key: "LoginBypassEnabled", type: Bool.self)
    static var isLoginBypassEnabled: Bool?
#endif
    
    static func clearAll() {
        UserDefaults.standard.dictionaryRepresentation().keys.forEach {
            UserDefaults.standard.removeObject(forKey: $0.description)
        }
    }
}

@propertyWrapper
struct UserDefaultsItem<T> {
    let key: String
    let type: T.Type
    
    var wrappedValue: T? {
        get {
            return UserDefaults.standard.object(forKey: key) as? T
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
