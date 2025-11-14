//
//  FillButton.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/13/25.
//

import SwiftUI

struct FillButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    init(
        title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            } else {
                Text(title)
                    .font(.appSubTitle)
                    .foregroundStyle(.white)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(isEnabled ? AppColor.primary : AppColor.disabled)
        .disabled(!isEnabled || isLoading)
        .customRadius()
    }
}
