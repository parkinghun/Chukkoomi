//
//  PaymentClient.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.
//

import ComposableArchitecture
import Foundation
import WebKit
import iamport_ios

/// 결제 관련 기능을 담당하는 Dependency
@DependencyClient
struct PaymentClient {
    /// IamportPayment 객체 생성
    var createPayment: @Sendable (
        _ amount: String,
        _ productName: String,
        _ buyerName: String,
        _ postId: String
    ) -> IamportPayment = { _, _, _, _ in
        IamportPayment(
            pg: PG.html5_inicis.makePgRawName(pgId: "INIpayTest"),
            merchant_uid: "default_merchant_uid",
            amount: "0"
        )
    }

    /// WKWebView를 통한 결제 요청 및 서버 검증
    var requestPayment: @Sendable (
        _ webView: WKWebView,
        _ payment: IamportPayment,
        _ postId: String
    ) async throws -> PaymentResponseDTO

    /// 결제 영수증 검증
    var validatePayment: @Sendable (
        _ impUid: String,
        _ postId: String
    ) async throws -> PaymentResponseDTO

    /// 결제 내역 조회
    var fetchPayments: @Sendable () async throws -> PaymentListResponseDTO
}

// MARK: - DependencyKey

extension PaymentClient: DependencyKey {
    static let liveValue: PaymentClient = {
        let service = PaymentService.shared

        return PaymentClient(
            createPayment: { amount, productName, buyerName, postId in
                service.createPayment(
                    amount: amount,
                    productName: productName,
                    buyerName: buyerName,
                    postId: postId
                )
            },
            requestPayment: { webView, payment, postId in
                try await service.requestPayment(
                    webView: webView,
                    payment: payment,
                    postId: postId
                )
            },
            validatePayment: { impUid, postId in
                try await service.validatePayment(
                    impUid: impUid,
                    postId: postId
                )
            },
            fetchPayments: {
                try await service.fetchPayments()
            }
        )
    }()

    /// 테스트용 Mock 구현
    static let testValue: PaymentClient = PaymentClient()

    /// Preview용 Mock 구현 (성공 시뮬레이션)
    static let previewValue: PaymentClient = PaymentClient(
        createPayment: { amount, productName, buyerName, postId in
            let merchantUid = "preview_\(postId)_\(Int(Date().timeIntervalSince1970*1000))"
            return IamportPayment(
                pg: PG.html5_inicis.makePgRawName(pgId: "INIpayTest"),
                merchant_uid: merchantUid,
                amount: amount
            ).then {
                $0.pay_method = PayMethod.card.rawValue
                $0.name = productName
                $0.buyer_name = buyerName
                $0.app_scheme = "portone"
            }
        },
        requestPayment: { _, _, postId in
            // Mock 성공 응답
            PaymentResponseDTO(
                buyerId: "preview_user",
                postId: postId,
                merchantUid: "preview_merchant_\(postId)",
                productName: "Preview Filter",
                price: 1000,
                paidAt: "2024-01-01T00:00:00Z"
            )
        },
        validatePayment: { _, postId in
            // Mock 성공 응답
            PaymentResponseDTO(
                buyerId: "preview_user",
                postId: postId,
                merchantUid: "preview_merchant_\(postId)",
                productName: "Preview Filter",
                price: 1000,
                paidAt: "2024-01-01T00:00:00Z"
            )
        },
        fetchPayments: {
            // Mock 빈 목록
            PaymentListResponseDTO(data: [])
        }
    )
}

// MARK: - DependencyValues Extension

extension DependencyValues {
    var payment: PaymentClient {
        get { self[PaymentClient.self] }
        set { self[PaymentClient.self] = newValue }
    }
}
