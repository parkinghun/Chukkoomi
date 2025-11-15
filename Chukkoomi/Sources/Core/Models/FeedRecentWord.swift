//
//  FeedRecentWord.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import Foundation

struct FeedRecentWord: Equatable {
    let id: String
    let userId: String
    let keyword: String
    let searchedAt: Date
}

extension FeedRecentWord {
    var toDTO: FeedRecentWordDTO {
        return FeedRecentWordDTO(id: id, userId: userId, keyword: keyword, searchedAt: searchedAt)
    }
}
