//
//  Post.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/5/25.
//

import Foundation

struct Post: Identifiable, Equatable {
    let id: String
    let teams: FootballTeams
    let title: String
    let price: Int
    let content: String
#warning("values - 데이터 확정 시 수정 필요")
    let values: [String]
    let createdAt: Date?
    let creator: User?
    let files: [String]
    let likes: [String]?
    let bookmarks: [String]?
    let buyers: [String]?
    let hashTags: [String]
    let commentCount: Int?
    let location: GeoLocation
    let distance: Double?

    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id
    }
}

extension Post {
    /// 게시글 작성 & 수정시 사용하는 생성자
    init(
        teams: FootballTeams,
        title: String,
        price: Int,
        content: String,
        values: [String] = [],
        files: [String] = [],
        location: GeoLocation = .defaultLocation
    ) {
        self.id = UUID().uuidString
        self.teams = teams
        self.title = title
        self.price = price
        self.content = content
        self.values = values
        self.createdAt = nil
        self.creator = nil
        self.files = files
        self.likes = nil
        self.bookmarks = nil
        self.buyers = nil
        self.hashTags = []
        self.commentCount = nil
        self.location = location
        self.distance = nil
    }
    
    var toDTO: PostRequestDTO {
        return PostRequestDTO(
            category: teams.rawValue,
            title: title,
            price: price,
            content: content,
            value1: values.count > 0 ? values[0] : "",
            value2: values.count > 1 ? values[1] : "",
            value3: values.count > 2 ? values[2] : "",
            value4: values.count > 3 ? values[3] : "",
            value5: values.count > 4 ? values[4] : "",
            value6: values.count > 5 ? values[5] : "",
            value7: values.count > 6 ? values[6] : "",
            value8: values.count > 7 ? values[7] : "",
            value9: values.count > 8 ? values[8] : "",
            value10: values.count > 9 ? values[9] : "",
            files: files,
            longitude: location.longitude,
            latitude: location.latitude
        )
    }
}

// MARK: - 축구 팀 카테고리
enum FootballTeams: String, CaseIterable {
    case all = "전체"

    // K리그 팀들
    case ulsan = "울산 HD FC"
    case jeonbuk = "전북 현대 모터스"
    case pohang = "포항 스틸러스"
    case suwonFC = "수원 FC"
    case kimcheon = "김천상무 FC"
    case gangwon = "강원 FC"
    case jeju = "제주 유나이티드"
    case anyang = "FC 안양"
    case seoul = "FC 서울"
    case gwangju = "광주 FC"
    case daejeon = "대전 하나 시티즌"
    case daegu = "대구 FC"

    // 숨김 카테고리 (결제 전용)
    case payment = "결제"

    /// UI에서 숨겨야 하는 카테고리인지
    var isHidden: Bool {
        self == .payment
    }

    /// 사용자에게 보여질 카테고리 목록
    static var visibleCategories: [FootballTeams] {
        allCases.filter { !$0.isHidden }
    }

    /// KLeagueTeam과 매핑
    var kLeagueTeam: KLeagueTeam? {
        switch self {
        case .ulsan: return KLeagueTeam.allTeams.first { $0.koreanName == "울산 HD FC" }
        case .jeonbuk: return KLeagueTeam.allTeams.first { $0.koreanName == "전북 현대 모터스" }
        case .pohang: return KLeagueTeam.allTeams.first { $0.koreanName == "포항 스틸러스" }
        case .suwonFC: return KLeagueTeam.allTeams.first { $0.koreanName == "수원 FC" }
        case .kimcheon: return KLeagueTeam.allTeams.first { $0.koreanName == "김천상무 FC" }
        case .gangwon: return KLeagueTeam.allTeams.first { $0.koreanName == "강원 FC" }
        case .jeju: return KLeagueTeam.allTeams.first { $0.koreanName == "제주 유나이티드" }
        case .anyang: return KLeagueTeam.allTeams.first { $0.koreanName == "FC 안양" }
        case .seoul: return KLeagueTeam.allTeams.first { $0.koreanName == "FC 서울" }
        case .gwangju: return KLeagueTeam.allTeams.first { $0.koreanName == "광주 FC" }
        case .daejeon: return KLeagueTeam.allTeams.first { $0.koreanName == "대전 하나 시티즌" }
        case .daegu: return KLeagueTeam.allTeams.first { $0.koreanName == "대구 FC" }
        case .all, .payment: return nil
        }
    }

    /// 한글 이름으로 FootballTeams 찾기
    static func from(koreanName: String) -> FootballTeams? {
        allCases.first { $0.rawValue == koreanName }
    }
}

struct GeoLocation: Equatable {
    let longitude: Double
    let latitude: Double

    static let defaultLocation = GeoLocation(
        longitude: 126.886417,
        latitude: 37.517682
    )
}
