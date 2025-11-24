//
//  StickerStripView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

struct StickerStripView: View {
    let availableStickers: [String]
    let onStickerTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
        .frame(height: 100)
    }
}

// MARK: - Sticker Item Button
struct StickerItemButton: View {
    let imageName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
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
