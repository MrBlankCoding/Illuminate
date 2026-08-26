//
//  ChromeVersionResponseTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Testing
import Foundation
@testable import Illuminate

struct ChromeVersionResponseTests {

    @Test func decodesStableChannelVersion() throws {
        let json = """
        {
          "channels": {
            "Stable": { "channel": "Stable", "version": "140.0.7339.0" },
            "Beta": { "channel": "Beta", "version": "141.0.0.0" }
          }
        }
        """
        let decoded = try JSONDecoder().decode(ChromeVersionResponse.self, from: Data(json.utf8))
        #expect(decoded.channels.stable.version == "140.0.7339.0")
    }

    @Test func missingStableChannelThrows() {
        let json = #"{"channels": {"Beta": {"version": "1.0.0.0"}}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ChromeVersionResponse.self, from: Data(json.utf8))
        }
    }

    @MainActor
    @Test func freshCacheShortCircuitsNetworkFetch() async {
        let defaults = UserDefaults.standard
        defaults.set("99.0.0.0", forKey: "ChromeVersionFetcher.cachedVersion")
        defaults.set(Date(), forKey: "ChromeVersionFetcher.cachedDate")

        let version = await ChromeVersionFetcher.fetchLatestStableVersion()
        #expect(version == "99.0.0.0")

        defaults.removeObject(forKey: "ChromeVersionFetcher.cachedVersion")
        defaults.removeObject(forKey: "ChromeVersionFetcher.cachedDate")
    }
}
