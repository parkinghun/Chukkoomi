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

        func setWebView(_ webView: WKWebView) {
            // 다음 런루프에서 안전하게 설정
            DispatchQueue.main.async { [weak self] in
                self?.webView = webView
            }
        }
    }
}

// MARK: - 사용 예시 (주석)

/*
 사용 예시:

 struct PaymentView: View {
     @State private var webView: WKWebView?
     private let paymentService = PaymentService.shared

     var body: some View {
         VStack {
             // 결제 버튼
             Button("결제하기") {
                 if let webView = webView {
                     let payment = paymentService.createPayment(
                         amount: "1000",
                         productName: "테스트 상품",
                         buyerName: "홍길동",
                         postId: "post123"
                     )

                     paymentService.requestPayment(
                         webView: webView,
                         payment: payment
                     ) { response in
                         handlePaymentResponse(response)
                     }
                 }
             }

             // WebView (화면에 보이지 않게 숨김 처리 가능)
             IamportWebView(webView: $webView)
                 .frame(width: 0, height: 0)
                 .hidden()
         }
     }

     private func handlePaymentResponse(_ response: IamportResponse?) {
         guard let response = response else {
             print("결제 응답 없음")
             return
         }

         if response.success == true {
             // 결제 성공 - 서버 검증
             if let impUid = response.imp_uid {
                 Task {
                     do {
                         let validated = try await paymentService.validatePayment(
                             impUid: impUid,
                             postId: "post123"
                         )
                         print("결제 검증 완료: \(validated)")
                     } catch {
                         print("결제 검증 실패: \(error)")
                     }
                 }
             }
         } else {
             // 결제 실패
             print("결제 실패: \(response.error_msg ?? "알 수 없는 오류")")
         }
     }
 }
 */
