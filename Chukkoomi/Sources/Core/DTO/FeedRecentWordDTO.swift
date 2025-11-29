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
    @Persisted var userId: String
    @Persisted var keyword: String
    @Persisted var searchedAt: Date

    convenience init(userId: String, keyword: String, searchedAt: Date) {
        self.init()
        self.id = ObjectId.generate()
        self.userId = userId
        self.keyword = keyword
        self.searchedAt = searchedAt
    }

    convenience init(id: String, userId: String, keyword: String, searchedAt: Date) {
        self.init()
        if let objectId = try? ObjectId(string: id) {
            self.id = objectId
        } else {
            self.id = ObjectId.generate()
        }
        self.userId = userId
        self.keyword = keyword
        self.searchedAt = searchedAt
    }
}

extension FeedRecentWordDTO {
    var toDomain: FeedRecentWord {
        return FeedRecentWord(id: id.stringValue, userId: userId, keyword: keyword, searchedAt: searchedAt)
    }
}
