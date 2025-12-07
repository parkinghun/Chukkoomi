//
//  CropControlView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

/// 크롭 컨트롤 뷰
/// - 비율 선택 (자유/1:1/3:4 등)
/// - 리셋/적용 버튼
struct CropControlView: View {
    let selectedAspectRatio: EditPhotoFeature.CropAspectRatio
    let cropRect: CGRect?
    let onAspectRatioChanged: (EditPhotoFeature.CropAspectRatio) -> Void
    let onResetCrop: () -> Void
    let onApplyCrop: () -> Void

    // MARK: - Constants

    /// 컨트롤 뷰 전체 높이
    private let controlHeight: CGFloat = 120
    /// 비율 버튼 간격
    private let ratioButtonSpacing: CGFloat = 8
    /// 버튼 가로 패딩
    private let buttonHorizontalPadding: CGFloat = 12
    /// 버튼 세로 패딩
    private let buttonVerticalPadding: CGFloat = 8
    /// 액션 버튼 세로 패딩
    private let actionButtonVerticalPadding: CGFloat = 12
    /// 버튼 모서리 반경
    private let buttonCornerRadius: CGFloat = 8

    var body: some View {
        VStack(spacing: 12) {
            // 비율 선택 스크롤
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ratioButtonSpacing) {
                    ForEach(EditPhotoFeature.CropAspectRatio.allCases) { ratio in
                        ratioButton(for: ratio)
                    }
                }
                .padding(.horizontal, 20)
            }

            // 리셋/적용 버튼
            HStack(spacing: 12) {
                actionButton(
                    title: "리셋",
                    isActive: true,
                    action: onResetCrop
                )

                actionButton(
                    title: "적용",
                    isActive: cropRect != nil,
                    action: onApplyCrop
                )
                .disabled(cropRect == nil)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: controlHeight)
    }

    // MARK: - View Components

    /// 비율 선택 버튼
    private func ratioButton(for ratio: EditPhotoFeature.CropAspectRatio) -> some View {
        Button {
            onAspectRatioChanged(ratio)
        } label: {
            Text(ratio.rawValue)
                .font(.caption)
                .padding(.horizontal, buttonHorizontalPadding)
                .padding(.vertical, buttonVerticalPadding)
                .background(
                    Capsule()
                        .fill(selectedAspectRatio == ratio ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(selectedAspectRatio == ratio ? Color.white : Color.primary)
        }
    }

    /// 액션 버튼 (리셋/적용)
    private func actionButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, actionButtonVerticalPadding)
                .background(isActive ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isActive ? Color.white : Color.primary)
                .cornerRadius(buttonCornerRadius)
        }
    }
}
