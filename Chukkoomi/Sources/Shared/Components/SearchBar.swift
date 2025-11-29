//
//  SearchBar.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/11/25.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let placeholder: String
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: AppPadding.small) {
            AppIcon.search
                .foregroundStyle(AppColor.textSecondary)

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit {
                    onSubmit()
                }

            if !text.isEmpty {
                Button {
                    onClear()
                } label: {
                    AppIcon.xmarkCircleFill
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppPadding.medium)
        .padding(.vertical, AppPadding.small)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AppColor.divider, lineWidth: 1)
        )
        .frame(height: 40)
    }
}
