//
//  AppPadding.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/4/25.
//

import Foundation

/// ex) Text("").padding(AppSpacing.large)
enum AppPadding {
    /// 가장 바깥 패딩
    static let large: CGFloat = 20
    /// 섹션 구분 패딩
    static let medium: CGFloat = 12
    /// 섹션 내 컴포넌트 패딩
    static let small: CGFloat = 8
    /// 화면 최하단 패딩
    static let bottom: CGFloat = 20
}
