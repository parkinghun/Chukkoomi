//
//  PaymentService.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/26/25.
//

import Foundation
import WebKit
import iamport_ios

/// 결제 관련 네트워크 작업을 담당하는 서비스 프로토콜
protocol PaymentServiceProtocol {
    /// 결제 영수증 검증
    func validatePayment(impUid: String, postId: String) async throws -> PaymentResponseDTO
    
    /// 결제 내역 조회
    func fetchPayments() async throws -> PaymentListResponseDTO
}

/// PaymentService 실제 구현
final class PaymentService: PaymentServiceProtocol {
    
    static let shared = PaymentService()
    
    private let networkManager: NetworkManager
    
    // MARK: - Iamport 설정 (나중에 AppInfo로 이동 가능)
    private let iamportUserCode = APIInfo.iamportUserCode
    private let appScheme = "portone" // TODO: Info.plist의 URL Scheme과 동일하게 설정
    
    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }
    
    // MARK: - 결제 데이터 생성
    
    /// IamportPayment 객체 생성
    /// - Parameters:
    ///   - amount: 결제 금액
    ///   - productName: 상품명
    ///   - buyerName: 구매자명(실명)
    ///   - postId: 게시글 ID (merchant_uid에 포함)
    /// - Returns: 생성된 IamportPayment 객체
    func createPayment(
        amount: String,
        productName: String,
        buyerName: String,
        postId: String
    ) -> IamportPayment {
        // merchant_uid 생성 (중복 방지를 위해 timestamp + postId 사용)
        let merchantUid = "ios_\(postId)_\(Int(Date().timeIntervalSince1970*1000))"
        
        let payment = IamportPayment(
            pg: PG.html5_inicis.makePgRawName(pgId: "INIpayTest"),
            merchant_uid: merchantUid,
            amount: amount
        ).then {
            $0.pay_method = PayMethod.card.rawValue
            $0.name = productName
            $0.buyer_name = buyerName
            $0.app_scheme = appScheme
        }
        
        return payment
    }
    
    // MARK: - 결제 요청

    /// WKWebView를 통한 결제 요청 및 서버 검증 (async/await)
    /// - Parameters:
    ///   - webView: 결제에 사용할 WKWebView
    ///   - payment: 결제 데이터
    ///   - postId: 게시글 ID (서버 검증에 사용)
    /// - Returns: 검증된 결제 정보
    /// - Throws: PaymentError
    ///
    /// # 결제 플로우
    /// 1. Iamport SDK를 통해 결제 요청
    /// 2. 결제 완료 시 imp_uid를 포함한 응답 수신
    /// 3. imp_uid와 postId를 서버로 전송하여 유효성 검증
    /// 4. 검증된 결제 정보 반환
    func requestPayment(
        webView: WKWebView,
        payment: IamportPayment,
        postId: String
    ) async throws -> PaymentResponseDTO {
        print("💳 [PaymentService] 결제 요청 시작")
        print("   → userCode: \(iamportUserCode)")
        print("   → merchant_uid: \(payment.merchant_uid)")
        print("   → name: \(payment.name ?? "없음")")

        // Iamport SDK의 completion handler를 async/await로 변환
        let iamportResponse = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<IamportResponse, Error>) in
            print("   → Iamport SDK 호출...")
            Iamport.shared.paymentWebView(
                webViewMode: webView,
                userCode: iamportUserCode,
                payment: payment
            ) { iamportResponse in
                print("   → Iamport SDK 응답 수신")
                if let response = iamportResponse {
                    print("   → success: \(response.success ?? false)")
                    print("   → imp_uid: \(response.imp_uid ?? "없음")")
                    continuation.resume(returning: response)
                } else {
                    print("❌ Iamport 응답이 nil")
                    continuation.resume(throwing: PaymentError.invalidResponse)
                }
            }
        }

        // 결제 성공 여부 확인
        guard iamportResponse.success == true else {
            let errorMessage = iamportResponse.error_msg ?? "알 수 없는 결제 오류"
            print("결제 실패: \(errorMessage)")
            throw PaymentError.paymentFailed(message: errorMessage)
        }

        // imp_uid 확인
        guard let impUid = iamportResponse.imp_uid else {
            print("imp_uid 없음")
            throw PaymentError.invalidResponse
        }

        print("결제 승인 완료")
        print("   - imp_uid: \(impUid)")
        print("   - merchant_uid: \(iamportResponse.merchant_uid ?? "없음")")

        // 서버 영수증 검증
        do {
            let validated = try await validatePayment(impUid: impUid, postId: postId)
            print("서버 검증 완료")
            print("   - 구매자: \(validated.buyerId)")
            print("   - 상품: \(validated.productName)")
            print("   - 금액: \(validated.price)원")
            return validated
        } catch {
            print("❌ 서버 검증 실패: \(error)")
            throw PaymentError.validationFailed
        }
    }
    
    // MARK: - 서버 영수증 검증
    
    /// 결제 영수증 서버 검증
    /// - Parameters:
    ///   - impUid: 아임포트 결제 고유번호
    ///   - postId: 게시글 ID
    /// - Returns: 검증된 결제 정보
    func validatePayment(impUid: String, postId: String) async throws -> PaymentResponseDTO {
        let request = ValidatePaymentRequestDTO(impUid: impUid, postId: postId)
        
        return try await networkManager.performRequest(
            PaymentRouter.validatePayment(request),
            as: PaymentResponseDTO.self
        )
    }
    
    // MARK: - 결제 내역 조회
    
    /// 내 결제 내역 조회
    /// - Returns: 결제 내역 리스트
    func fetchPayments() async throws -> PaymentListResponseDTO {
        return try await networkManager.performRequest(
            PaymentRouter.fetchPayments,
            as: PaymentListResponseDTO.self
        )
    }
}

// MARK: - 결제 에러

enum PaymentError: Error, LocalizedError {
    case paymentFailed(message: String)
    case validationFailed
    case userCancelled
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .paymentFailed(let message):
            return "결제 실패: \(message)"
        case .validationFailed:
            return "결제 검증 실패"
        case .userCancelled:
            return "사용자가 결제를 취소했습니다"
        case .invalidResponse:
            return "유효하지 않은 결제 응답"
        }
    }
}
