//
//  SignUpView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import SwiftUI
import ComposableArchitecture

struct SignUpView: View {

    let store: StoreOf<SignUpFeature>
    @Environment(\.dismiss) var dismiss
    @State private var isPasswordVisible = false
    @State private var isPasswordConfirmVisible = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 상단 헤더
                ZStack {
                    Text("회원가입")
                        .font(.system(size: 17, weight: .semibold))

                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.black)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 0) {
                        // 타이틀
                        VStack(alignment: .leading, spacing: 4) {
                            Text("회원가입")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)

                            Text("회원여부 확인 및 가입을 진행합니다.")
                                .font(.system(size: 13))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                        VStack(spacing: 16) {
                            // 이메일 입력 필드 + 중복확인
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    TextField(
                                        "이메일을 입력해주세요",
                                        text: viewStore.binding(
                                            get: \.email,
                                            send: SignUpFeature.Action.emailChanged
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

                                    // 중복 확인 버튼
                                    Button {
                                        viewStore.send(.checkEmailButtonTapped)
                                    } label: {
                                        Text("중복확인")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 16)
                                            .background(AppColor.primary)
                                            .cornerRadius(8)
                                    }
                                    .disabled(viewStore.email.isEmpty || viewStore.isLoading)
                                    .opacity(viewStore.email.isEmpty || viewStore.isLoading ? 0.5 : 1.0)
                                }

                                // 이메일 검증 결과 또는 에러 메시지 (이메일 입력 필드 바로 아래)
                                if let isEmailValid = viewStore.isEmailValid {
                                    Text(isEmailValid ? "사용 가능한 이메일 입니다." : "중복된 이메일 입니다.")
                                        .font(.system(size: 12))
                                        .foregroundColor(isEmailValid ? .green : AppColor.primary)
                                        .padding(.leading, 4)
                                } else if let errorMessage = viewStore.errorMessage {
                                    Text(errorMessage)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColor.primary)
                                        .padding(.leading, 4)
                                }
                            }

                            // 비밀번호 입력 필드
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .trailing) {
                                    Group {
                                        if isPasswordVisible {
                                            TextField(
                                                "비밀번호를 입력해주세요",
                                                text: viewStore.binding(
                                                    get: \.password,
                                                    send: SignUpFeature.Action.passwordChanged
                                                )
                                            )
                                        } else {
                                            SecureField(
                                                "비밀번호를 입력해주세요",
                                                text: viewStore.binding(
                                                    get: \.password,
                                                    send: SignUpFeature.Action.passwordChanged
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

                                // 비밀번호 유효성 검사
                                if !viewStore.password.isEmpty && viewStore.password.count < 8 {
                                    Text("8자이상 입력해주세요.")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColor.primary)
                                        .padding(.leading, 4)
                                }
                            }

                            // 비밀번호 확인 입력 필드
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .trailing) {
                                    Group {
                                        if isPasswordConfirmVisible {
                                            TextField(
                                                "비밀번호를 입력해주세요",
                                                text: viewStore.binding(
                                                    get: \.passwordConfirm,
                                                    send: SignUpFeature.Action.passwordConfirmChanged
                                                )
                                            )
                                        } else {
                                            SecureField(
                                                "비밀번호를 입력해주세요",
                                                text: viewStore.binding(
                                                    get: \.passwordConfirm,
                                                    send: SignUpFeature.Action.passwordConfirmChanged
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

                                    // 비밀번호 확인 보기 토글 버튼
                                    Button {
                                        isPasswordConfirmVisible.toggle()
                                    } label: {
                                        Image(systemName: isPasswordConfirmVisible ? "eye.fill" : "eye.slash.fill")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 16)
                                    }
                                }

                                // 비밀번호 일치 검사
                                if !viewStore.passwordConfirm.isEmpty && viewStore.password != viewStore.passwordConfirm {
                                    Text("비밀번호가 일치하지 않습니다.")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColor.primary)
                                        .padding(.leading, 4)
                                }
                            }

                            // 닉네임 입력 필드
                            TextField(
                                "닉네임을 입력해주세요",
                                text: viewStore.binding(
                                    get: \.nickname,
                                    send: SignUpFeature.Action.nicknameChanged
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

                            Spacer()

                            // 회원가입 버튼
                            Button {
                                viewStore.send(.signUpButtonTapped)
                            } label: {
                                if viewStore.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                } else {
                                    Text("가입완료")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                }
                            }
                            .background(isSignUpButtonEnabled(viewStore) ? AppColor.primary : AppColor.disabled)
                            .cornerRadius(8)
                            .disabled(!isSignUpButtonEnabled(viewStore) || viewStore.isLoading)
                            .padding(.bottom, 40)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .onChange(of: viewStore.shouldDismiss) {
                if viewStore.shouldDismiss {
                    dismiss()
                }
            }
        }
        .alert(store: store.scope(state: \.$alert, action: \.alert))
    }

    // 가입완료 버튼 활성화 조건
    private func isSignUpButtonEnabled(_ viewStore: ViewStore<SignUpFeature.State, SignUpFeature.Action>) -> Bool {
        return !viewStore.email.isEmpty &&
               !viewStore.nickname.isEmpty &&
               !viewStore.password.isEmpty &&
               !viewStore.passwordConfirm.isEmpty &&
               viewStore.isEmailValid == true
    }
}
