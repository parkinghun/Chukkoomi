//
//  EditProfileView.swift
//  Chukkoomi
//
//  Created by Claude on 11/8/25.
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
                            .padding(.top, AppPadding.small)
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
                        .fill(AppColor.primary)
                        .frame(width: 32, height: 32)
                        .overlay {
                            AppIcon.camera
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                }
            }
        }
    }

    // MARK: - 닉네임 섹션
    private func nicknameSection(viewStore: ViewStoreOf<EditProfileFeature>) -> some View {
        VStack(alignment: .leading, spacing: AppPadding.small) {
            Text("닉네임")
                .font(.appBody)
                .fontWeight(.semibold)
                .foregroundStyle(.gray)

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

            HStack {
                if !viewStore.nickname.isEmpty {
                    if !viewStore.isNicknameCharacterValid {
                        Text("한글, 영문, 숫자만 사용 가능합니다 (특수문자 불가)")
                            .font(.appCaption)
                            .foregroundColor(.red)
                    } else if !viewStore.isNicknameLengthValid {
                        Text("닉네임은 공백 없이 2~8자여야 합니다")
                            .font(.appCaption)
                            .foregroundColor(.red)
                    }
                }
                Spacer()
                Text("\(viewStore.nickname.count)/8")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 소개 문구 섹션
    private func introduceSection(viewStore: ViewStoreOf<EditProfileFeature>) -> some View {
        VStack(alignment: .leading, spacing: AppPadding.small) {
            Text("소개")
                .font(.appBody)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

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

            HStack {
                if !viewStore.isIntroduceValid {
                    Text("소개는 20자 이내여야 합니다")
                        .font(.appCaption)
                        .foregroundColor(.red)
                }
                Spacer()
                Text("\(viewStore.introduce.count)/20")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }
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
            .navigationDestination(
                store: store.scope(state: \.$galleryPicker, action: \.galleryPicker)
            ) { store in
                GalleryPickerView(store: store)
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
