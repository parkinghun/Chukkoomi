//
//  PaymentRouter.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/26/25.
//

import Foundation

enum PaymentRouter {
    /// 결제 영수증 검증
    case validatePayment(ValidatePaymentRequestDTO)
    /// 결제 내역 조회
    case fetchPayments
}

extension PaymentRouter: Router {
    
    var version: String { return "v1" }
    
    var path: String {
        switch self {
        case .validatePayment:
            return "/\(version)/payments/validation"
        case .fetchPayments:
            return "/\(version)/payments/me"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .validatePayment:
            return .post
        case .fetchPayments:
            return .get
        }
    }
    
    var headers: [HTTPHeader]? {
        return HTTPHeader.basic
    }
    
    var body: AnyEncodable? {
        switch self {
        case .validatePayment(let dto):
            return .init(dto)
        case .fetchPayments:
            return nil
        }
    }
    
    var bodyEncoder: BodyEncoder? {
        switch self {
        case .validatePayment:
            return .json

        case .fetchPayments:
            return nil
        }
    }
    
    var query: [HTTPQuery]? {
        return nil
    }
}
