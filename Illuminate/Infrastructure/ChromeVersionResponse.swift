//
//  ChromeVersionResponse.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/9/26.
//

import Foundation

struct ChromeVersionResponse: Codable {
    let channels: Channels

    struct Channels: Codable {
        let stable: Channel

        enum CodingKeys: String, CodingKey {
            case stable = "Stable"
        }
    }

    struct Channel: Codable {
        let version: String
    }
}


final class ChromeVersionFetcher {

    private static let cachedVersionKey = "ChromeVersionFetcher.cachedVersion"
    private static let cachedDateKey = "ChromeVersionFetcher.cachedDate"

    private static let cacheTTL: TimeInterval = 7 * 24 * 60 * 60

    private static let fallbackVersion = "139.0.0.0"


    static func fetchLatestStableVersion() async -> String {

        if let cached = cachedVersion(), isCacheFresh() {
            return cached
        }

        if let fetched = await fetchFromNetwork() {
            persist(version: fetched)
            return fetched
        }

        let fallback = cachedVersion() ?? fallbackVersion

        if cachedVersion() == nil {
            AppLog.info("Chrome version fetch failed; using \(fallback) (cached=\(cachedVersion() != nil))")
        }

        return fallback
    }


    private static func fetchFromNetwork() async -> String? {

        guard let url = URL(string:
            "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json"
        ) else {
            return nil
        }

        do {
            let (data, response) = try await Task.detached(priority: .utility) {
                try await URLSession.shared.data(from: url)
            }.value

            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(
                ChromeVersionResponse.self,
                from: data
            )

            return decoded.channels.stable.version

        } catch {
            AppLog.error("Failed to fetch Chrome version", error: error)
            return nil
        }
    }


    private static func isCacheFresh() -> Bool {
        guard let date = UserDefaults.standard.object(
            forKey: cachedDateKey
        ) as? Date else {
            return false
        }

        return Date().timeIntervalSince(date) < cacheTTL
    }


    private static func cachedVersion() -> String? {
        UserDefaults.standard.string(forKey: cachedVersionKey)
    }


    private static func persist(version: String) {
        UserDefaults.standard.set(version, forKey: cachedVersionKey)
        UserDefaults.standard.set(Date(), forKey: cachedDateKey)
    }
}
