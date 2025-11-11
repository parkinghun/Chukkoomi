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

    /// 메인 텍스트 색상
    static let textPrimary = Color(hex: "#000000")
    /// 보조 텍스트 색상
    static let textSecondary = Color(hex: "#007AFF")

    /// 구분 선 색상
    static let divider = Color(hex: "#C7C7C7")
    /// 배경색
    static let background = Color(hex: "#FFFFFF")
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
