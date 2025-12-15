//
//  Comment.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/10/25.
//

import Foundation

struct Comment: Identifiable, Equatable {
    let id: String
    let content: String
    let createdAt: Date
    let creator: User
}
