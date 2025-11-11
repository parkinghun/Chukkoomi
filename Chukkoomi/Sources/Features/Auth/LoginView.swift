//
//  LoginView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import SwiftUI
import ComposableArchitecture

struct LoginView: View {

    let store: StoreOf<LoginFeature>
    @State private var isPasswordVisible = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 상단 타이틀
                Text("로그인")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                // 로고
                Image(systemName: "soccerball.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(AppColor.primary)
                    .padding(.top, 40)

                Spacer()

                // 로그인 폼
                VStack(spacing: 12) {
                    // 이메일 입력 필드
                    TextField(
                        "이메일을 입력해주세요",
                        text: viewStore.binding(
                            get: \.email,
                            send: LoginFeature.Action.emailChanged
                        )
                    )
                    .padding()
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)

                    // 비밀번호 입력 필드
                    ZStack(alignment: .trailing) {
                        Group {
                            if isPasswordVisible {
                                TextField(
                                    "비밀번호를 입력해주세요",
                                    text: viewStore.binding(
                                        get: \.password,
                                        send: LoginFeature.Action.passwordChanged
                                    )
                                )
                            } else {
                                SecureField(
                                    "비밀번호를 입력해주세요",
                                    text: viewStore.binding(
                                        get: \.password,
                                        send: LoginFeature.Action.passwordChanged
                                    )
                                )
                            }
                        }
                        .padding()
                        .padding(.trailing, 40)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)

                        // 비밀번호 보기 토글 버튼
                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 16)
                        }
                    }

                    // 에러 메시지
                    if let errorMessage = viewStore.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(AppColor.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    // 로그인 버튼
                    Button {
                        viewStore.send(.loginButtonTapped)
                    } label: {
                        if viewStore.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        } else {
                            Text("로그인")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }
                    }
                    .background(isLoginButtonEnabled(viewStore) ? AppColor.primary : AppColor.disabled)
                    .cornerRadius(12)
                    .disabled(!isLoginButtonEnabled(viewStore) || viewStore.isLoading)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)

                // 간편 로그인
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)

                        Text("간편 로그인")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    HStack(spacing: 16) {
                        // 카카오 로그인
                        Button {
                            // TODO: 카카오 로그인
                        } label: {
                            Image(systemName: "message.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.black)
                                .padding(16)
                                .background(Color.yellow)
                                .clipShape(Circle())
                        }

                        // 애플 로그인
                        Button {
                            // TODO: 애플 로그인
                        } label: {
                            Image(systemName: "apple.logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.black)
                                .clipShape(Circle())
                        }
                    }

                    // 이메일 회원가입
                    NavigationLink {
                        SignUpView(store: Store(initialState: SignUpFeature.State()) {
                            SignUpFeature()
                        })
                    } label: {
                        Text("이메일 회원가입")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .underline()
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
            .onDisappear {
                viewStore.send(.clearFields)
            }
        }
    }

    // 로그인 버튼 활성화 조건 (최소 조건: 빈 값이 아닐 것)
    private func isLoginButtonEnabled(_ viewStore: ViewStore<LoginFeature.State, LoginFeature.Action>) -> Bool {
        return !viewStore.email.isEmpty && !viewStore.password.isEmpty
    }
}
