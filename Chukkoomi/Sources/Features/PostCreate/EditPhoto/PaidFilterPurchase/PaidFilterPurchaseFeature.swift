//
//  PaidFilterPurchaseFeature.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.

//

import ComposableArchitecture
import Foundation
import WebKit

/// 유료 필터 구매 기능을 담당하는 Feature
@Reducer
struct PaidFilterPurchaseFeature {

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        /// WebView (결제 UI)
        var webView: WKWebView?

        /// 구매하려는 필터
        var pendingFilter: PaidFilter

        /// 결제 진행 중 여부
        var isProcessingPayment: Bool = false

        /// 결제 에러 메시지
        var paymentError: String?

        /// 사용 가능한 유료 필터 목록
        var availableFilters: [PaidFilter] = []

        /// 구매한 필터의 postId 목록
        var purchasedFilterPostIds: Set<String> = []

        /// 구매한 ImageFilter 타입 계산
        var purchasedFilterTypes: Set<ImageFilter> {
            Set(availableFilters
                .filter { purchasedFilterPostIds.contains($0.id) }
                .map { $0.imageFilter }
            )
        }

        init(
            pendingFilter: PaidFilter,
            availableFilters: [PaidFilter] = [],
            purchasedFilterPostIds: Set<String> = []
        ) {
            self.pendingFilter = pendingFilter
            self.availableFilters = availableFilters
            self.purchasedFilterPostIds = purchasedFilterPostIds
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        /// WebView 생성 완료
        case webViewCreated(WKWebView)

        /// 구매 버튼 탭 (실제로는 webView 생성 시 자동 시작)
        case purchaseButtonTapped

        /// 결제 완료 (성공/실패)
        case paymentCompleted(Result<PaymentResponseDTO, PaymentError>)

        /// 취소 버튼 탭
        case cancelButtonTapped

        /// Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            /// 결제 성공
            case purchaseCompleted(PaymentResponseDTO)

            /// 결제 취소
            case purchaseCancelled
        }
    }

    // MARK: - Dependencies
    @Dependency(\.payment) var payment
    @Dependency(\.purchase) var purchase

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .webViewCreated(webView):
                state.webView = webView

                // WebView 생성되면 자동으로 결제 시작
                guard !state.isProcessingPayment else {
                    return .none
                }

                state.isProcessingPayment = true
                state.paymentError = nil

                let filter = state.pendingFilter
                let paymentData = payment.createPayment(
                    "\(filter.price)",
                    filter.title,
                    "사용자",  // TODO: 실제 사용자 이름으로 변경
                    filter.id
                )

                return .run { [payment] send in
                    do {
                        let validated = try await payment.requestPayment(
                            webView,
                            paymentData,
                            filter.id
                        )
                        await send(.paymentCompleted(.success(validated)))
                    } catch let error as PaymentError {
                        await send(.paymentCompleted(.failure(error)))
                    } catch {
                        await send(.paymentCompleted(.failure(.invalidResponse)))
                    }
                }

            case .purchaseButtonTapped:
                // 현재는 webView 생성 시 자동으로 결제가 시작되므로
                // 이 액션은 명시적으로 재시도할 때만 사용
                guard let webView = state.webView else {
                    return .none
                }

                state.isProcessingPayment = true
                state.paymentError = nil

                let filter = state.pendingFilter
                let paymentData = payment.createPayment(
                    "\(filter.price)",
                    filter.title,
                    "사용자",
                    filter.id
                )

                return .run { [payment] send in
                    do {
                        let validated = try await payment.requestPayment(
                            webView,
                            paymentData,
                            filter.id
                        )
                        await send(.paymentCompleted(.success(validated)))
                    } catch let error as PaymentError {
                        await send(.paymentCompleted(.failure(error)))
                    } catch {
                        await send(.paymentCompleted(.failure(.invalidResponse)))
                    }
                }

            case let .paymentCompleted(.success(paymentDTO)):
                state.isProcessingPayment = false
                state.paymentError = nil

                // 로컬 캐시에 구매 기록 저장
                state.purchasedFilterPostIds.insert(paymentDTO.postId)

                return .run { [purchase] send in
                    await purchase.markAsPurchased(paymentDTO.postId)
                    await send(.delegate(.purchaseCompleted(paymentDTO)))
                }

            case let .paymentCompleted(.failure(error)):
                state.isProcessingPayment = false
                state.paymentError = error.localizedDescription
                return .none

            case .cancelButtonTapped:
                return .send(.delegate(.purchaseCancelled))

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Action Equatable Conformance
extension PaidFilterPurchaseFeature.Action {
    static func == (lhs: PaidFilterPurchaseFeature.Action, rhs: PaidFilterPurchaseFeature.Action) -> Bool {
        switch (lhs, rhs) {
        case (.webViewCreated, .webViewCreated):
            return true  // WKWebView는 비교 불가, 항상 true
        case (.purchaseButtonTapped, .purchaseButtonTapped):
            return true
        case (.cancelButtonTapped, .cancelButtonTapped):
            return true
        case let (.paymentCompleted(l), .paymentCompleted(r)):
            switch (l, r) {
            case let (.success(ls), .success(rs)):
                return ls == rs
            case let (.failure(lf), .failure(rf)):
                return lf.localizedDescription == rf.localizedDescription
            default:
                return false
            }
        case let (.delegate(l), .delegate(r)):
            return l == r
        default:
            return false
        }
    }
}
