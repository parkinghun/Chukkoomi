//
//  TextControlView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

struct TextControlView: View {
    let isTextEditMode: Bool
    let currentTextColor: Color
    let onColorChanged: (Color) -> Void

    private let colors: [Color] = [
        .white, .black, .red, .orange,
        .yellow, .green, .blue, .purple
    ]

    var body: some View {
        VStack(spacing: 0) {
            if isTextEditMode {
                // 색상 선택 버튼들 (편집 모드일 때만)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(currentTextColor == color ? Color.white : Color.clear, lineWidth: 2)
                                )
                                .overlay(
                                    // 흰색 원도 보이도록 테두리 추가
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                )
                                .onTapGesture {
                                    onColorChanged(color)
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .background(Color.black.opacity(0.2))
            }
        }
    }
}
