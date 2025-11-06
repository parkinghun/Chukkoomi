//
//  PaymentDTO.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/6/25.
//

import Foundation

// MARK: - 결제 영수증 검증 Request
struct ValidatePaymentRequestDTO: Encodable {
    let impUid: String
    let postId: String
    
    enum CodingKeys: String, CodingKey {
        case impUid = "imp_uid"
        case postId = "post_id"
    }
}

// MARK: - 결제 Response (검증 + 내역 공통)
struct PaymentResponseDTO: Decodable {
    let buyerId: String
    let postId: String
    let merchantUid: String
    let productName: String
    let price: Int
    let paidAt: String
    
    enum CodingKeys: String, CodingKey {
        case buyerId = "buyer_id"
        case postId = "post_id"
        case merchantUid = "merchant_uid"
        case productName
        case price
        case paidAt
    }
}

// MARK: - 결제 내역 리스트 Response
struct PaymentListResponseDTO: Decodable {
    let data: [PaymentResponseDTO]
}

// MARK: - DTO -> Entity
extension PaymentResponseDTO {
    var toDomain: Payment {
        return Payment(
            buyerId: buyerId,
            postId: postId,
            merchantUid: merchantUid,
            productName: productName,
            price: price,
            paidAt: paidAt
        )
    }
}
