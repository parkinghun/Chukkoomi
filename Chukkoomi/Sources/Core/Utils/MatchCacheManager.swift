//
//  MatchCacheManager.swift
//  Chukkoomi
//
//  Created by 박성훈 on 11/12/25.
//

import Foundation

/// 경기 데이터 캐싱 매니저
enum MatchCacheManager {
    private static let userDefaults = UserDefaults.standard
    private static let matchesKey = "cachedMatches"
    private static let lastFetchDateKey = "lastMatchesFetchDate"

    /// 경기 데이터를 캐시에 저장
    /// - Parameter matches: 저장할 경기 배열
    static func saveMatches(_ matches: [Match]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(matches)
            userDefaults.set(data, forKey: matchesKey)

            // 현재 날짜 저장 (오늘 날짜만 저장)
            let today = Calendar.current.startOfDay(for: Date())
            userDefaults.set(today, forKey: lastFetchDateKey)

            print("경기 데이터 캐시 저장 완료: \(matches.count)개")
        } catch {
            print("❌ 경기 데이터 캐시 저장 실패: \(error)")
        }
    }

    /// 캐시된 경기 데이터 불러오기
    /// - Returns: 캐시된 경기 배열 (없으면 nil)
    static func loadMatches() -> [Match]? {
        // 오늘 날짜와 마지막 fetch 날짜 비교
        guard shouldUseCachedData() else {
            print("캐시가 만료되었거나 없습니다. API 호출이 필요합니다.")
            return nil
        }

        // 캐시된 데이터 불러오기
        guard let data = userDefaults.data(forKey: matchesKey) else {
            print("캐시된 경기 데이터가 없습니다.")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let matches = try decoder.decode([Match].self, from: data)
            print("캐시된 경기 데이터 로드 완료: \(matches.count)개")
            return matches
        } catch {
            print("경기 데이터 캐시 로드 실패: \(error)")
            return nil
        }
    }

    /// 캐시된 데이터를 사용해도 되는지 확인
    /// - Returns: 오늘 날짜에 이미 fetch했으면 true, 아니면 false
    private static func shouldUseCachedData() -> Bool {
        guard let lastFetchDate = userDefaults.object(forKey: lastFetchDateKey) as? Date else {
            print("마지막 fetch 날짜 없음")
            return false
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastFetch = calendar.startOfDay(for: lastFetchDate)

        let isSameDay = calendar.isDate(today, inSameDayAs: lastFetch)

        if isSameDay {
            print("오늘 이미 데이터를 받았습니다. 캐시 사용.")
        } else {
            print("새로운 날입니다. API 호출 필요.")
        }

        return isSameDay
    }

    /// 캐시된 데이터 삭제 (테스트/디버깅용)
    static func clearCache() {
        userDefaults.removeObject(forKey: matchesKey)
        userDefaults.removeObject(forKey: lastFetchDateKey)
        print("경기 데이터 캐시 삭제 완료")
    }
}
