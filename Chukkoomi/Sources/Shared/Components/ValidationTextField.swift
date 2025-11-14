//
//  ValidationTextField.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/14/25.
//

import SwiftUI

struct ValidationTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let validationMessage: String

    init(placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, validationMessage: String) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.validationMessage = validationMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppPadding.small) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.value)
                        .stroke(AppColor.divider, lineWidth: 1)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .frame(height: 40)
                .frame(maxWidth: .infinity)

            Text(validationMessage.isEmpty ? " " : validationMessage)
                .font(.appCaption)
                .foregroundColor(.red)
                .frame(height: 16)
        }
    }
}
