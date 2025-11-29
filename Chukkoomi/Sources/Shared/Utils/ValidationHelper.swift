//
//  ValidationHelper.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/14/25.
//

import Foundation

enum ValidationHelper {

    // MARK: - Nickname Validation

    /// 닉네임 길이 검증 (2-8자, 공백 불가)
    static func isNicknameLengthValid(_ nickname: String) -> Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 &&
               trimmed.count <= 8 &&
               !nickname.contains(" ")
    }

    /// 닉네임 문자 검증 (한글, 영문, 숫자만 허용)
    static func isNicknameCharacterValid(_ nickname: String) -> Bool {
        let allowedCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "가-힣ㄱ-ㅎㅏ-ㅣ"))
        let nicknameCharacterSet = CharacterSet(charactersIn: nickname)
        return allowedCharacters.isSuperset(of: nicknameCharacterSet)
    }

    /// 닉네임 전체 검증
    static func isNicknameValid(_ nickname: String) -> Bool {
        return isNicknameLengthValid(nickname) && isNicknameCharacterValid(nickname)
    }

    /// 닉네임 검증 메시지
    static func nicknameValidationMessage(_ nickname: String) -> String {
        if nickname.isEmpty {
            return "닉네임을 입력해주세요"
        } else if !isNicknameCharacterValid(nickname) {
            return "한글, 영문, 숫자만 사용 가능합니다 (특수문자 불가)"
        } else if !isNicknameLengthValid(nickname) {
            return "닉네임은 공백 없이 2~8자여야 합니다"
        } else {
            return ""
        }
    }

    // MARK: - Introduce Validation

    /// 소개 문구 검증 (20자 이내)
    static func isIntroduceValid(_ introduce: String) -> Bool {
        return introduce.count <= 20
    }

    /// 소개 문구 검증 메시지
    static func introduceValidationMessage(_ introduce: String) -> String {
        if !isIntroduceValid(introduce) {
            return "소개는 20자 이내여야 합니다"
        } else {
            return ""
        }
    }
}
