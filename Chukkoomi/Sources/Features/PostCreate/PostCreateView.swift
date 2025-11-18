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
                title: buttonTitle,
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
        .navigationTitle(store.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(
            store: store.scope(state: \.$galleryPicker, action: \.galleryPicker)
        ) { store in
            NavigationStack {
                GalleryPickerView(store: store)
            }
        }
        .alert(alertTitle, isPresented: Binding(
            get: { store.showSuccessAlert },
            set: { _ in store.send(.dismissSuccessAlert) }
        )) {
            Button("확인", role: .cancel) {
                store.send(.dismissSuccessAlert)
            }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 버튼 타이틀
    private var buttonTitle: String {
        if store.isUploading {
            return store.isEditMode ? "수정 중..." : "업로드 중..."
        } else {
            return store.isEditMode ? "수정하기" : "업로드"
        }
    }

    // MARK: - 알림 타이틀/메시지
    private var alertTitle: String {
        store.isEditMode ? "수정 완료" : "업로드 완료"
    }

    private var alertMessage: String {
        store.isEditMode ? "게시글이 성공적으로 수정되었습니다." : "게시글이 성공적으로 업로드되었습니다."
    }

    // MARK: - Media Selection Section
    private var mediaSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = store.selectedImageData,
               let uiImage = UIImage(data: imageData) {
                // 새로 선택된 이미지 표시
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
            } else if let originalImageUrl = store.originalImageUrl {
                // 수정 모드: 기존 이미지 표시
                ZStack(alignment: .topTrailing) {
                    AsyncMediaImageView(
                        imagePath: originalImageUrl,
                        width: UIScreen.main.bounds.width - 32,
                        height: 200,
                        onImageLoaded: { _ in }
                    )
                    .frame(height: 200)
                    .background(Color.black)
                    .cornerRadius(12)

                    // 변경 버튼
                    Button {
                        store.send(.selectImageTapped)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                            Text("변경")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
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

    // MARK: - Content Section
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("글쓰기")
                .font(.headline)

            HashtagTextView(
                text: Binding(
                    get: { store.content },
                    set: { store.send(.contentChanged($0)) }
                ),
                placeholder: "내용을 입력하세요. 해시태그는 #을 붙여주세요 (ex. #손흥민)"
            )
            .frame(height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - HashtagTextView
struct HashtagTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        // Placeholder 설정
        if text.isEmpty {
            textView.text = placeholder
            textView.textColor = UIColor.gray.withAlphaComponent(0.5)
        } else {
            textView.text = text
            textView.textColor = UIColor.label
            applyHashtagFormatting(to: textView)
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Binding 값이 변경되었을 때만 업데이트
        if uiView.text != text {
            if text.isEmpty {
                uiView.text = placeholder
                uiView.textColor = UIColor.gray.withAlphaComponent(0.5)
            } else {
                uiView.text = text
                uiView.textColor = UIColor.label
                applyHashtagFormatting(to: uiView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyHashtagFormatting(to textView: UITextView) {
        let attributedString = NSMutableAttributedString(string: textView.text)
        let fullRange = NSRange(location: 0, length: attributedString.length)

        // 기본 스타일 설정
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

        // 해시태그 패턴: #으로 시작하고 공백이나 줄바꿈 전까지
        let pattern = "#[^\\s#]+"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: textView.text, options: [], range: fullRange)

            for match in matches {
                // 해시태그에 파란색 + 밑줄 적용
                attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }

        textView.attributedText = attributedString
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: HashtagTextView

        init(_ parent: HashtagTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // Placeholder 제거
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            // 텍스트가 비어있으면 Placeholder 표시
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.gray.withAlphaComponent(0.5)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            // Placeholder가 아닐 때만 업데이트
            if textView.text != parent.placeholder {
                parent.text = textView.text
                parent.applyHashtagFormatting(to: textView)
            }
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


