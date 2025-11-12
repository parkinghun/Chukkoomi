//
//  EditProfileView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/8/25.
//

import SwiftUI
import ComposableArchitecture

struct EditProfileView: View {
    let store: StoreOf<EditProfileFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // 프로필 이미지
                        profileImageSection(viewStore: viewStore)
                            .padding(.top, AppPadding.large)

                        // 닉네임 입력
                        nicknameSection(viewStore: viewStore)
                            .padding(.top, AppPadding.large)

                        // 소개 문구 입력
                        introduceSection(viewStore: viewStore)
                            .padding(.top, AppPadding.medium)
                    }
                    .padding(.horizontal, AppPadding.large)
                }
                .onTapGesture {
                    hideKeyboard()
                }

                // 완료 버튼
                completeButton(viewStore: viewStore)
            }
            .navigationTitle("프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            // 네비게이션 연결
            .modifier(EditProfileNavigation(store: store))
        }
    }

    // MARK: - Helper
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - 프로필 이미지 섹션
    private func profileImageSection(viewStore: ViewStoreOf<EditProfileFeature>) -> some View {
        VStack(spacing: AppPadding.small) {
            Button {
                viewStore.send(.profileImageTapped)
            } label: {
                Group {
                    if let imageData = viewStore.profileImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                AppIcon.personFill
                                    .foregroundColor(.gray)
                                    .font(.system(size: 40))
                            }
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(.white)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Circle()
                                .stroke(AppColor.divider, lineWidth: 1)
                        }
                        .overlay {
                            AppIcon.camera
                                .foregroundColor(.black)
                                .font(.system(size: 16))
                        }
                }
            }
        }
    }

    // MARK: - 닉네임 섹션
    private func nicknameSection(viewStore: ViewStoreOf<EditProfileFeature>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("닉네임을 입력하세요", text: viewStore.binding(
                get: \.nickname,
                send: { .nicknameChanged($0) }
            ))
            .textFieldStyle(.plain)
            .padding()
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.small.rawValue)
                    .stroke(AppColor.divider, lineWidth: 1)
            )

            Group {
                if viewStore.nickname.isEmpty {
                    Text("닉네임을 입력해주세요")
                } else if !viewStore.isNicknameCharacterValid {
                    Text("한글, 영문, 숫자만 사용 가능합니다 (특수문자 불가)")
                } else if !viewStore.isNicknameLengthValid {
                    Text("닉네임은 공백 없이 2~8자여야 합니다")
                } else {
                    Text(" ")
                }
            }
            .font(.appCaption)
            .foregroundColor(.red)
            .frame(height: 16)
        }
    }

    // MARK: - 소개 문구 섹션
    private func introduceSection(viewStore: ViewStoreOf<EditProfileFeature>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("소개를 입력하세요", text: viewStore.binding(
                get: \.introduce,
                send: { .introduceChanged($0) }
            ))
            .textFieldStyle(.plain)
            .padding()
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.small.rawValue)
                    .stroke(AppColor.divider, lineWidth: 1)
            )

            Group {
                if !viewStore.isIntroduceValid {
                    Text("소개는 20자 이내여야 합니다")
                } else {
                    Text(" ")
                }
            }
            .font(.appCaption)
            .foregroundColor(.red)
            .frame(height: 16)
        }
    }
    
    // MARK: - 완료 버튼
    private func completeButton(viewStore: ViewStoreOf<EditProfileFeature>) -> some View {
        Button {
            viewStore.send(.saveButtonTapped)
        } label: {
            if viewStore.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            } else {
                Text("수정 완료")
                    .font(.appBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
        }
        .background(viewStore.canSave ? AppColor.primary : AppColor.disabled)
        .disabled(!viewStore.canSave || viewStore.isLoading)
        .customRadius(.small)
        .padding(.horizontal, AppPadding.large)
        .padding(.bottom, AppPadding.large)
    }
}

// MARK: - Navigation 구성
private struct EditProfileNavigation: ViewModifier {
    let store: StoreOf<EditProfileFeature>

    func body(content: Content) -> some View {
        content
            .fullScreenCover(
                store: store.scope(state: \.$galleryPicker, action: \.galleryPicker)
            ) { store in
                NavigationStack {
                    GalleryPickerView(store: store)
                }
            }
    }
}

// MARK: - Preview
//#Preview {
//    let sampleProfile = Profile(
//        userId: "user123",
//        email: "user@example.com",
//        nickname: "사용자",
//        profileImage: nil,
//        introduce: "안녕하세요!",
//        followers: [],
//        following: [],
//        posts: []
//    )
//
//    return NavigationStack {
//        EditProfileView(
//            store: Store(
//                initialState: EditProfileFeature.State(profile: sampleProfile)
//            ) {
//                EditProfileFeature()
//            }
//        )
//    }
//}
