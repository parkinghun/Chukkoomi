//
//  PaidFilterPurchaseView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 12/15/25.
//

import SwiftUI
import ComposableArchitecture
import WebKit

struct PaidFilterPurchaseView: View {
    @Bindable var store: StoreOf<PaidFilterPurchaseFeature>
    let displayImage: UIImage  // EditPhotoFeature에서 전달받는 미리보기 이미지

    var body: some View {
        ZStack {
            // 반투명 배경
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    store.send(.cancelButtonTapped)
                }

            // 중앙 모달 카드
            VStack(spacing: 20) {
                // X 버튼
                HStack {
                    Spacer()

                    Text(store.pendingFilter.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        store.send(.cancelButtonTapped)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    }
                }

                // 필터 설명
                Text(store.pendingFilter.content)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                // 필터 미리보기 이미지 (적용된 이미지)
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)

                // 가격
                Text("₩\(store.pendingFilter.price)")
                    .font(.title)
                    .fontWeight(.bold)

                // 에러 메시지
                if let errorMessage = store.paymentError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }

                // 구매 버튼
                Button {
                    store.send(.purchaseButtonTapped)
                } label: {
                    if store.isProcessingPayment {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("구매하기")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(store.isProcessingPayment ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(store.isProcessingPayment)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 40)

            // WebView Overlay (결제 진행 중일 때만)
            if store.isProcessingPayment {
                ZStack {
                    Color.black.opacity(0.9)
                        .ignoresSafeArea()

                    IamportWebView(webView: Binding(
                        get: { store.webView },
                        set: { webView in
                            if let webView = webView {
                                print("🌐 [PaidFilterPurchaseView] WebView 생성됨")
                                store.send(.webViewCreated(webView))
                            }
                        }
                    ))
                    .background(Color.white)
                }
            }
        }
    }
}
