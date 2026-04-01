//
//  WebKitManagerTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/18/26.
//

import Testing
import WebKit
@testable import Illuminate

struct WebKitManagerTests {

    @Test func makeConfigurationCreatesDistinctConfigurations() async throws {
        await MainActor.run {
            let manager = WebKitManager(profile: BrowserProfile(name: "Test Profile"))

            let first = manager.makeConfiguration()
            let second = manager.makeConfiguration()

            #expect(first !== second)
            #expect(first.userContentController !== second.userContentController)
        }
    }

    @Test func makeConfigurationRespectsCookieSetting() async throws {
        await MainActor.run {
            let manager = WebKitManager(profile: BrowserProfile(name: "Test Profile"))
            let originalValue = manager.cookiesEnabled
            defer { manager.cookiesEnabled = originalValue }

            manager.cookiesEnabled = true
            let persistentConfiguration = manager.makeConfiguration()

            manager.cookiesEnabled = false
            let ephemeralConfiguration = manager.makeConfiguration()

            #expect(persistentConfiguration.websiteDataStore.isPersistent)
            #expect(ephemeralConfiguration.websiteDataStore.isPersistent == false)
        }
    }
}
