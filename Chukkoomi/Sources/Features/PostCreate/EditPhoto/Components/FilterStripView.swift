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
    let purchasedFilterTypes: Set<ImageFilter>
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
                        isPurchased: isPurchased(filter),
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
    
    private func isPurchased(_ filter: ImageFilter) -> Bool {
        guard filter.isPaid else { return true }
        
        // 캐시된 purchasedFilterTypes에서 확인 (동기적으로)
        return purchasedFilterTypes.contains(filter)
    }
}

// MARK: - Filter Thumbnail View
struct FilterThumbnailView: View {
    let filter: ImageFilter
    let thumbnail: UIImage?
    let isSelected: Bool
    let isPurchased: Bool
    let onTap: () -> Void
    let onDragStart: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
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
                
                if filter.isPaid {
                    (isPurchased ? AppIcon.unlock : AppIcon.lock)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(isPurchased ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                        .clipShape(Circle())
                        .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.gray : Color.clear, lineWidth: 3)
                    .frame(width: 80, height: 80)
            )
            .draggable(filter) {
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
            
            Text(filter.rawValue)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .black : .gray)
        }
    }
}
