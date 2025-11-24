//
//  CropControlView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

struct CropControlView: View {
    let selectedAspectRatio: EditPhotoFeature.CropAspectRatio
    let cropRect: CGRect?
    let onAspectRatioChanged: (EditPhotoFeature.CropAspectRatio) -> Void
    let onResetCrop: () -> Void
    let onApplyCrop: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // 비율 선택 버튼들
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EditPhotoFeature.CropAspectRatio.allCases) { ratio in
                        Button {
                            onAspectRatioChanged(ratio)
                        } label: {
                            Text(ratio.rawValue)
                                .font(Font.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedAspectRatio == ratio ? Color.blue : Color.gray.opacity(0.2))
                                )
                                .foregroundColor(selectedAspectRatio == ratio ? Color.white : Color.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // 적용/리셋 버튼
            HStack(spacing: 12) {
                Button {
                    onResetCrop()
                } label: {
                    Text("리셋")
                        .font(Font.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(Color.primary)
                        .cornerRadius(8)
                }

                Button {
                    onApplyCrop()
                } label: {
                    Text("적용")
                        .font(Font.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(cropRect != nil ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(Color.white)
                        .cornerRadius(8)
                }
                .disabled(cropRect == nil)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 120)
    }
}
