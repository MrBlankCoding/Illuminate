//
//  AdBlockTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/9/26.
//

import Testing
import Foundation
import WebKit
@testable import Illuminate

@MainActor
struct AdBlockTests {

    private nonisolated func createTestUserDefaults() -> UserDefaults {
        let suiteName = "AdBlockTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func testContentRuleListCreation() async throws {
        let adBlock = AdBlockService(userDefaults: createTestUserDefaults())
        adBlock.prepareIfNeeded()
        
        // Give it more time for potentially large EasyList parsing and compilation
        var attempts = 0
        while adBlock.contentRuleList == nil && attempts < 10 {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            attempts += 1
        }
        
        #expect(adBlock.isEnabled == true, "AdBlock should be enabled by default")
        #expect(adBlock.contentRuleList != nil, "Content rule list should be created when enabled after \(attempts) seconds")
    }

    @Test func testToggleAdBlock() async throws {
        let userDefaults = createTestUserDefaults()
        userDefaults.set(false, forKey: "adBlockEnabled")
        
        let adBlock = AdBlockService(userDefaults: userDefaults)
        #expect(adBlock.isEnabled == false, "AdBlock should be disabled when stored value is false")
        #expect(adBlock.contentRuleList == nil, "Content rule list should be nil when disabled")
        
        // Enable
        adBlock.isEnabled = true
        adBlock.prepareIfNeeded()
        
        var attempts = 0
        while adBlock.contentRuleList == nil && attempts < 10 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            attempts += 1
        }
        
        #expect(adBlock.contentRuleList != nil, "Content rule list should be created when enabled")
        
        // Disable
        adBlock.isEnabled = false
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(adBlock.contentRuleList == nil, "Content rule list should be nil when disabled")
    }

    @Test func testAllowlist() async throws {
        let adBlock = AdBlockService(userDefaults: createTestUserDefaults())
        adBlock.prepareIfNeeded()
        
        var attempts = 0
        while adBlock.contentRuleList == nil && attempts < 10 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            attempts += 1
        }
        
        #expect(adBlock.contentRuleList != nil, "Content rule list should exist")
        
        adBlock.addAllowlistHost("doubleclick.net")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        #expect(adBlock.contentRuleList != nil, "Content rule list should still exist after allowlist update")
    }
}
