//
//  PostCreateView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/16/25.
//

import SwiftUI
import ComposableArchitecture

struct PostCreateView: View {
    let store: StoreOf<PostCreateFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            mediaSelectionSection

            categorySection

            hashtagSection

            contentSection

            Spacer()

            // 에러 메시지
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // 업로드 버튼
            FillButton(
                title: store.isUploading ? "업로드 중..." : "업로드",
                isLoading: store.isUploading,
                isEnabled: store.canUpload
            ) {
                store.send(.uploadButtonTapped)
            }
        }
        .padding(.horizontal, AppPadding.large)
        .padding(.vertical, 16)
        .dismissKeyboardOnTap()
        .keyboardDoneButton()
        .fullScreenCover(
            store: store.scope(state: \.$galleryPicker, action: \.galleryPicker)
        ) { store in
            NavigationStack {
                GalleryPickerView(store: store)
            }
        }
        .alert("업로드 완료", isPresented: Binding(
            get: { store.showSuccessAlert },
            set: { _ in store.send(.dismissSuccessAlert) }
        )) {
            Button("확인", role: .cancel) {
                store.send(.dismissSuccessAlert)
            }
        } message: {
            Text("게시글이 성공적으로 업로드되었습니다.")
        }
    }

    // MARK: - Media Selection Section
    private var mediaSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = store.selectedImageData,
               let uiImage = UIImage(data: imageData) {
                // 선택된 이미지/영상 표시
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.black)
                        .cornerRadius(12)

                    // 제거 버튼
                    Button {
                        store.send(.removeImage)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(8)
                }
            } else {
                // 이미지 선택 버튼
                Button {
                    store.send(.selectImageTapped)
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                        Text("사진/영상 선택")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Category Section
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("카테고리")
                .font(.headline)

            Menu {
                ForEach(FootballTeams.visibleCategories, id: \.self) { category in
                    Button {
                        store.send(.categorySelected(category))
                    } label: {
                        Text(category.rawValue)
                    }
                }
            } label: {
                HStack {
                    Text(store.selectedCategory.rawValue)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Hashtag Section
    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("해시태그")
                .font(.headline)

            // 해시태그 입력 필드
            TextField("해시태그를 입력해주세요(ex. 손흥민)", text: Binding(
                get: { store.hashtagInput },
                set: { store.send(.hashtagInputChanged($0)) }
            ))
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                store.send(.addHashtag)
            }

            // 추가된 해시태그 표시
            if !store.hashtags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(store.hashtags, id: \.self) { tag in
                        hashtagChip(tag: tag)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Hashtag Chip
    private func hashtagChip(tag: String) -> some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.subheadline)
                .foregroundColor(.blue)

            Button {
                store.send(.removeHashtag(tag))
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Content Section
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Placeholder
                if store.content.isEmpty {
                    Text("글쓰기..")
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                // TextEditor
                TextEditor(text: Binding(
                    get: { store.content },
                    set: { store.send(.contentChanged($0)) }
                ))
                .frame(height: 200)
                .scrollContentBackground(.hidden)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - FlowLayout for Hashtags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            let position = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: position, proposal: .unspecified)
        }
    }

    struct FlowLayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // 다음 줄로
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))

                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(
                width: maxWidth,
                height: currentY + lineHeight
            )
        }
    }
}

#Preview {
    PostCreateView(
        store: Store(
            initialState: PostCreateFeature.State()
        ) {
            PostCreateFeature()
        }
    )
}


