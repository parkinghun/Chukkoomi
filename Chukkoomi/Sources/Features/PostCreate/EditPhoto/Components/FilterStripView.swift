//
//  FilterStripView.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

// MARK: - Filter Strip View
struct FilterStripView: View {
    let filterThumbnails: [ImageFilter: UIImage]
    let selectedFilter: ImageFilter
    let onFilterTap: (ImageFilter) -> Void
    let onFilterDragStart: (ImageFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ImageFilter.allCases) { filter in
                    FilterThumbnailView(
                        filter: filter,
                        thumbnail: filterThumbnails[filter],
                        isSelected: selectedFilter == filter,
                        onTap: {
                            onFilterTap(filter)
                        },
                        onDragStart: {
                            onFilterDragStart(filter)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 120)
    }
}

// MARK: - Filter Thumbnail View
struct FilterThumbnailView: View {
    let filter: ImageFilter
    let thumbnail: UIImage?
    let isSelected: Bool
    let onTap: () -> Void
    let onDragStart: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // 썸네일 이미지
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay {
                            ProgressView()
                                .tint(.gray)
                        }
                }
            }
            .overlay(
                // 선택 인디케이터
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.gray : Color.clear, lineWidth: 3)
                    .frame(width: 80, height: 80)
            )
            .draggable(filter) {
                // 드래그 중 미리보기
                VStack(spacing: 4) {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Text(filter.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onAppear {
                    onDragStart()
                }
            }
            .onTapGesture {
                onTap()
            }

            // 필터 이름
            Text(filter.rawValue)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .black : .gray)
        }
    }
}

//TODO: - 선택된게 업데이트 가 안됨 -> 텍스트 및 frame
//TODO: - 스티커는 do/undo가 안되는 이유
//TODO: - 전체 undo 했을 때, 그리기가 사라지는게 아니라 그리기가 적용된 필터가 사라짐. 그리기만 사라지고 싶음
