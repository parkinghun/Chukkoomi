//
//  FeedRecentWordDTO.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/12/25.
//

import Foundation
import RealmSwift

final class FeedRecentWordDTO: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var keyword: String
    @Persisted var searchedAt: Date

    convenience init(keyword: String, searchedAt: Date) {
        self.init()
        self.id = ObjectId.generate()
        self.keyword = keyword
        self.searchedAt = searchedAt
    }

    convenience init(id: String, keyword: String, searchedAt: Date) {
        self.init()
        if let objectId = try? ObjectId(string: id) {
            self.id = objectId
        } else {
            self.id = ObjectId.generate()
        }
        self.keyword = keyword
        self.searchedAt = searchedAt
    }
}

extension FeedRecentWordDTO {
    var toDomain: FeedRecentWord {
        return FeedRecentWord(id: id.stringValue, keyword: keyword, searchedAt: searchedAt)
    }
}
