//
//  TextControlView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

/// 텍스트 색상 선택 컨트롤 뷰
/// - 텍스트 편집 모드일 때 색상 팔레트 표시
/// - 선택된 색상 하이라이트
struct TextControlView: View {
    let isTextEditMode: Bool
    let currentTextColor: Color
    let onColorChanged: (Color) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isTextEditMode {
                // 색상 선택 버튼들 (편집 모드일 때만)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(AppColor.editingPalette, id: \.self) { color in
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
