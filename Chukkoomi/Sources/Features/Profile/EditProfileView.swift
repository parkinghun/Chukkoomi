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
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }

                VStack(spacing: AppPadding.large) {
                    // 프로필 이미지
                    profileImageSection(viewStore: viewStore)
                        .padding(.bottom, 20)

                    // 닉네임 입력
                    nicknameSection(viewStore: viewStore)

                    // 소개 문구 입력
                    introduceSection(viewStore: viewStore)

                    Spacer()

                    // 완료 버튼
                    completeButton(viewStore: viewStore)
                        .padding(.bottom, AppPadding.large)
                }
                .padding(.horizontal, AppPadding.large)
            }
            .navigationTitle("프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
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
                                    .foregroundStyle(.gray)
                                    .font(.system(size: 50))
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
                                .foregroundStyle(.black)
                                .font(.system(size: 16))
                        }
                }
            }
        }
    }

    // MARK: - 닉네임 섹션
    private func nicknameSection(viewStore: ViewStoreOf<EditProfileFeature>) -> some View {
        ValidationTextField(
            placeholder: "닉네임을 입력하세요",
            text: viewStore.binding(
                get: \.nickname,
                send: { .nicknameChanged($0) }
            ),
            validationMessage: viewStore.nicknameValidationMessage
        )
    }

    // MARK: - 소개 문구 섹션
    private func introduceSection(viewStore: ViewStoreOf<EditProfileFeature>) -> some View {
        ValidationTextField(
            placeholder: "소개를 입력하세요",
            text: viewStore.binding(
                get: \.introduce,
                send: { .introduceChanged($0) }
            ),
            validationMessage: viewStore.introduceValidationMessage,
        )
    }
    
    // MARK: - 완료 버튼
    private func completeButton(viewStore: ViewStoreOf<EditProfileFeature>) -> some View {
        FillButton(
            title: "수정 완료",
            isLoading: viewStore.isLoading,
            isEnabled: viewStore.canSave
        ) {
            viewStore.send(.saveButtonTapped)
        }
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
