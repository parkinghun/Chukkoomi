//
//  ThemeSelectionView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/22/25.
//

import SwiftUI

struct ThemeSelectionView: View {
    let selectedTheme: ChatFeature.ChatTheme
    let onThemeSelected: (ChatFeature.ChatTheme) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("채팅 테마 선택")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            .padding()

            // 테마 그리드
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(ChatFeature.ChatTheme.allCases, id: \.self) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: theme == selectedTheme
                        ) {
                            onThemeSelected(theme)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }
}

struct ThemeCard: View {
    let theme: ChatFeature.ChatTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 8) {
                // 테마 이미지 프리뷰
                ZStack {
                    if let imageName = theme.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .clipped()
                            .cornerRadius(12)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 150)
                            .cornerRadius(12)
                    }

                    // 선택 표시
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColor.primary, lineWidth: 3)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(AppColor.primary)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            )
                    }
                }

                // 테마 이름
                Text(theme.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
