//
//  EditableTextOverlayView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI

// MARK: - Editable Text Overlay View
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

        // 자동으로 포커스 및 키보드 표시
        DispatchQueue.main.async {
            textView.becomeFirstResponder()
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        uiView.textColor = UIColor(color)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: EditableTextOverlayView

        init(_ parent: EditableTextOverlayView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.onTextChanged(textView.text)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFinishEditing()
        }
    }
}
