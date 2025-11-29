//
//  AppFont.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/4/25.
//

import SwiftUI

/// ex) Text("제목").font(.appTitle)
extension Font {
    
    static var appMain: Font = .system(size: 20, weight: .semibold)
    
    static var appTitle: Font = .system(size: 17, weight: .semibold)
    /// FillButton
    static var appSubTitle: Font = .system(size: 15, weight: .semibold)
    
    /// 웬만하면 이거
    static var appBody: Font = .system(size: 17, weight: .regular)
    /// BorderButton
    static var appSubBody: Font = .system(size: 15, weight: .regular)
    
    /// 유효성 검사
    static var appCaption: Font = .system(size: 13, weight: .semibold)
    
    //MARK: - luckiestGuy 폰트
    static var luckiestGuyLarge: Font = .custom("LuckiestGuy-Regular", size: 30)
    static var luckiestGuyMedium: Font = .custom("LuckiestGuy-Regular", size: 24)
    
}
