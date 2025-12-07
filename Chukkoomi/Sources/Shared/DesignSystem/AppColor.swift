//
//  AppColor.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/4/25.
//

import SwiftUI

enum AppColor {
    /// 주조색
    static let primary = Color(hex: "#FE333D")
    /// 비활성화
    static let disabled = Color(hex: "#FD8C8C")
    
    /// 짙은 회색 배경 ex) 게시글 추가 버튼 배경
    static let darkGray = Color(hex: "#C7C7C7")
    /// 회색 배경 ex) 팔로우 버튼, 채팅 배경
    static let lightGray = Color(hex: "E7E8E8")
    
    static let pointColor = Color(hex: "DEFD09")
    
    /// 보조 텍스트
    static let textSecondary = Color.secondary
    
    /// 구분 선
    static let divider = Color(hex: "#D8DADC")

    /// 이미지 편집용 색상 팔레트 (텍스트, 그리기 등)
    static let editingPalette: [Color] = [
        .white, .black, .red, .orange,
        .yellow, .green, .blue, .purple
    ]
}


// MARK: - Color + HEX initializer
extension Color {
    init(hex: String, opacity: Double = 1.0) {
        var hexFormatted = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexFormatted = hexFormatted.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
