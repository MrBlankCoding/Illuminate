//
//  AdBlockServiceUnitTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/9/26.
//

import Testing
import Foundation
@testable import Illuminate

@Suite(.serialized)
@MainActor
struct AdBlockServiceUnitTests {

    private nonisolated func createTestUserDefaults() -> UserDefaults {
        let suiteName = "AdBlockServiceUnitTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private nonisolated func jsonContainsHost(_ json: String, _ host: String) -> Bool {
        if json.contains(host) { return true }
        let singleEscaped = host.replacingOccurrences(of: ".", with: "\\.")
        if json.contains(singleEscaped) { return true }
        let doubleEscaped = host.replacingOccurrences(of: ".", with: "\\\\.")
        if json.contains(doubleEscaped) { return true }
        return false
    }

    @Test func testDynamicJSONContainsBlockedHost() async throws {
        let userDefaults = createTestUserDefaults()
        let adBlock = AdBlockService(userDefaults: userDefaults)

        let host = "doubleclick.net"
        adBlock.updateBlockedHosts([host])

        // wait for dynamic JSON to be generated
        var attempts = 0
        while (adBlock.debug_lastGeneratedDynamicJSON ?? "").isEmpty && attempts < 10 {
            try await Task.sleep(nanoseconds: 200_000_000)
            attempts += 1
        }

        func jsonContainsHost(_ json: String, _ host: String) -> Bool {
            if json.contains(host) { return true }
            let singleEscaped = host.replacingOccurrences(of: ".", with: "\\.")
            if json.contains(singleEscaped) { return true }
            let doubleEscaped = host.replacingOccurrences(of: ".", with: "\\\\.")
            if json.contains(doubleEscaped) { return true }
            return false
        }

        #expect(jsonContainsHost(adBlock.debug_lastGeneratedDynamicJSON ?? "", host), "Dynamic JSON should contain the blocked host \(host)")
    }

    @Test func testStaticJSONIncludesSupplementaryDomain() async throws {
        let userDefaults = createTestUserDefaults()
        let adBlock = AdBlockService(userDefaults: userDefaults)

        adBlock.prepareIfNeeded()

        var attempts = 0
        while (adBlock.debug_lastGeneratedStaticJSON ?? "").isEmpty && attempts < 10 {
            try await Task.sleep(nanoseconds: 200_000_000)
            attempts += 1
        }

        #expect(jsonContainsHost(adBlock.debug_lastGeneratedStaticJSON ?? "", "doubleclick.net"), "Static JSON should include supplementary domain doubleclick.net")
    }

    @Test func testCaptchaProviderIsAllowlistedForContentRules() {
        let adBlock = AdBlockService(userDefaults: createTestUserDefaults())

        #expect(adBlock.isHostAllowlisted("www.google.com"))
        #expect(adBlock.isHostAllowlisted("challenges.cloudflare.com"))
    }

    @Test func testTrackerBlockedHostsAreMarkedThirdParty() async throws {
        let userDefaults = createTestUserDefaults()
        let adBlock = AdBlockService(userDefaults: userDefaults)

        let trackerHost = "analytics.google.com"
        adBlock.updateTrackerBlockedHosts([trackerHost])

        var attempts = 0
        while (adBlock.debug_lastGeneratedDynamicJSON ?? "").isEmpty && attempts < 10 {
            try await Task.sleep(nanoseconds: 200_000_000)
            attempts += 1
        }

        let json = adBlock.debug_lastGeneratedDynamicJSON ?? ""
        #expect(jsonContainsHost(json, "analytics.google.com"), "Dynamic JSON should contain tracker host")
        #expect(json.contains("third-party") || json.contains("load-type"), "Tracker rules should include third-party/load-type hint")
    }
}
