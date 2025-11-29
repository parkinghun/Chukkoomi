//
//  View+Keyboard.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/16/25.
//

import SwiftUI

// MARK: - Keyboard Helper
extension View {
    /// 키보드를 숨깁니다
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    /// 화면 터치 시 키보드를 자동으로 숨깁니다
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTap())
    }

    /// 키보드 위에 "완료" 버튼을 추가합니다
    func keyboardDoneButton() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    hideKeyboard()
                }
            }
        }
    }
}

// MARK: - DismissKeyboardOnTap Modifier
private struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    content.hideKeyboard()
                }

            content
        }
    }
}
