//
//  PostRequestDTO.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/10/25.
//

import Foundation

struct PostRequestDTO: Encodable {
    let category: String
    let title: String
    let price: Int
    let content: String
    let value1: String
    let value2: String
    let value3: String
    let value4: String
    let value5: String
    let value6: String
    let value7: String
    let value8: String
    let value9: String
    let value10: String
    /// 이미 업로드가 완료된 파일들의 URL(서버 저장 경로)
    var files: [String]
    let longitude: Double
    let latitude: Double
}
