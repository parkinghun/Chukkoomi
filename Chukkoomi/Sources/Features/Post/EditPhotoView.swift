//
//  EditPhotoView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/18/25.
//

import SwiftUI
import ComposableArchitecture

struct EditPhotoView: View {
    let store: StoreOf<GalleryPickerFeature.EditPhotoFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                // 선택된 이미지 표시 (16:9 비율)
                Color.black
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        Image(uiImage: viewStore.selectedImage)
                            .resizable()
                            .scaledToFit()
                    }

                Spacer()
            }
            .navigationTitle("사진 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewStore.send(.completeButtonTapped)
                    } label: {
                        Text("완료")
                            .foregroundStyle(.black)
                    }
                }
            }
        }
    }
}
