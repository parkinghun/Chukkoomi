//
//  IamportWebView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/26/25.
//

import SwiftUI
import WebKit

/// Iamport 결제를 위한 WKWebView 래퍼
@MainActor
struct IamportWebView: UIViewRepresentable {
    /// WKWebView를 외부에서 참조할 수 있도록 Binding
    @Binding var webView: WKWebView?

    func makeCoordinator() -> Coordinator {
        Coordinator(webView: $webView)
    }

    @MainActor
    func makeUIView(context: Context) -> WKWebView {
        // 메인 스레드에서 실행 보장
        let webView = WKWebView()
        webView.backgroundColor = .clear

        // Coordinator를 통해 안전하게 WebView 설정
        context.coordinator.setWebView(webView)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 업데이트 로직 (필요시 추가)
    }

    class Coordinator {
        @Binding var webView: WKWebView?

        init(webView: Binding<WKWebView?>) {
            _webView = webView
        }

        @MainActor
        func setWebView(_ webView: WKWebView) {
            // 다음 런루프에서 안전하게 설정
            DispatchQueue.main.async {
                self.webView = webView
            }
        }
    }
}
