//
//  BorderButton.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/13/25.
//

import SwiftUI

struct BorderButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.appSubTitle)
                .foregroundStyle(.black)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.value)
                        .stroke(AppColor.divider, lineWidth: 1)
                )
                .customRadius()
        }
    }
}
