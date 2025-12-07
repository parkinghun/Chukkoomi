//
//  EditableTextOverlayView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

// MARK: - Editable Text Overlay View

/// UITextView를 SwiftUI에서 사용하기 위한 래퍼
/// - 키보드 자동 표시
/// - 텍스트 실시간 업데이트
/// - 텍스트 편집 완료 콜백
struct EditableTextOverlayView: UIViewRepresentable {
    let text: String
    let color: Color
    let fontSize: CGFloat
    let onTextChanged: (String) -> Void
    let onFinishEditing: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.text = text
        textView.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        textView.textColor = UIColor(color)
        textView.backgroundColor = .clear
        textView.textAlignment = .center
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // 자동으로 포커스 및 키보드 표시 (Modern Concurrency)
        Task { @MainActor in
            textView.becomeFirstResponder()
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 텍스트가 실제로 변경된 경우만 업데이트
        if uiView.text != text {
            uiView.text = text
        }

        // 폰트 크기가 변경된 경우만 업데이트
        let newFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        if uiView.font != newFont {
            uiView.font = newFont
        }

        // 색상이 변경된 경우만 업데이트
        let newColor = UIColor(color)
        if uiView.textColor != newColor {
            uiView.textColor = newColor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextChanged: onTextChanged,
            onFinishEditing: onFinishEditing
        )
    }

    // MARK: - Coordinator

    /// UITextViewDelegate를 처리하는 Coordinator
    /// - 순환 참조 방지를 위해 클로저 캡처 사용
    class Coordinator: NSObject, UITextViewDelegate {
        let onTextChanged: (String) -> Void
        let onFinishEditing: () -> Void

        init(onTextChanged: @escaping (String) -> Void, onFinishEditing: @escaping () -> Void) {
            self.onTextChanged = onTextChanged
            self.onFinishEditing = onFinishEditing
        }

        func textViewDidChange(_ textView: UITextView) {
            onTextChanged(textView.text ?? "")
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            onFinishEditing()
        }
    }
}
