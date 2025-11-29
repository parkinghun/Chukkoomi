//
//  FileUploadDTO.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/10/25.
//

import Foundation

/// 파일 업로드 응답 DTO
/// multipart/form-data 는 DTO 없이 Data를 직접 업로드
/// 서버에서 받은 파일 경로를 PostResponseDTO의 files 배열에 넣어서 게시글 생성
struct FileUploadDTO: Decodable {
    let files: [String]
}
