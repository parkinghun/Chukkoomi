//
//  StickerStripView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

/// 스티커 선택 스트립 뷰
/// - 하단에 스크롤 가능한 스티커 목록 표시
/// - 스티커 선택 시 콜백 호출
struct StickerStripView: View {
    let availableStickers: [String]
    let onStickerTap: (String) -> Void

    // MARK: - Constants

    /// 스트립 전체 높이
    private static let stripHeight: CGFloat = 100
    /// 스티커 간 간격
    private static let itemSpacing: CGFloat = 12
    /// 스트립 모서리 반경
    private static let cornerRadius: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Self.itemSpacing) {
                ForEach(availableStickers, id: \.self) { stickerName in
                    StickerItemButton(
                        imageName: stickerName,
                        action: {
                            onStickerTap(stickerName)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
        .frame(height: Self.stripHeight)
    }
}

// MARK: - Sticker Item Button

/// 개별 스티커 버튼
struct StickerItemButton: View {
    let imageName: String
    let action: () -> Void

    // MARK: - Constants

    /// 스티커 버튼 크기
    private static let buttonSize: CGFloat = 60
    /// 버튼 내부 패딩
    private static let buttonPadding: CGFloat = 8
    /// 버튼 모서리 반경
    private static let buttonCornerRadius: CGFloat = 12

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .padding(Self.buttonPadding)
                .background(
                    RoundedRectangle(cornerRadius: Self.buttonCornerRadius)
                        .fill(Color.white.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Self.buttonCornerRadius)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        StickerStripView(
            availableStickers: (1...13).map { "sticker_\($0)" },
            onStickerTap: { _ in }
        )
        .padding()
    }
    .background(Color.gray.opacity(0.3))
}
