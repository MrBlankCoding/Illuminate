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
            let extensionManager = ExtensionManager(profileID: UUID())
            let manager = WebKitManager(profile: BrowserProfile(name: "Test Profile"), extensionManager: extensionManager)

            let first = manager.makeConfiguration()
            let second = manager.makeConfiguration()

            #expect(first !== second)
            #expect(first.userContentController !== second.userContentController)
        }
    }

    @Test func makeConfigurationRespectsCookieSetting() async throws {
        await MainActor.run {
            let extensionManager = ExtensionManager(profileID: UUID())
            let manager = WebKitManager(profile: BrowserProfile(name: "Test Profile"), extensionManager: extensionManager)
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

    @Test func guestConfigurationAlwaysUsesNonPersistentStore() async throws {
        await MainActor.run {
            let extensionManager = ExtensionManager(profileID: nil, isGuestSession: true)
            let manager = WebKitManager(profileID: nil, isPersistenceEnabled: false, extensionManager: extensionManager)
            let configuration = manager.makeConfiguration()

            #expect(configuration.websiteDataStore.isPersistent == false)
        }
    }

    @Test func makeConfigurationEnablesExpectedPlaybackAndContentDefaults() async throws {
        await MainActor.run {
            let extensionManager = ExtensionManager(profileID: UUID())
            let manager = WebKitManager(profile: BrowserProfile(name: "Test Profile"), extensionManager: extensionManager)
            let configuration = manager.makeConfiguration()

            #expect(configuration.mediaTypesRequiringUserActionForPlayback.isEmpty)
            #expect(configuration.defaultWebpagePreferences.allowsContentJavaScript)
            #expect(configuration.defaultWebpagePreferences.preferredContentMode == .desktop)
        }
    }
}
