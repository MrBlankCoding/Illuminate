//
//  BrowserShellModelTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import Testing
@testable import Illuminate

struct BrowserShellModelTests {
    @Test func profileUsesExpectedDefaultPresentationAndDownloadPreferences() {
        let profile = BrowserProfile(name: "Personal")

        #expect(profile.iconName == "person.crop.circle")
        #expect(profile.downloadPreferences.safeDownloadsOnly)
        #expect(!profile.downloadPreferences.revealInFinderWhenFinished)
    }

    @Test func profileInitializerPreservesProvidedValues() {
        let id = UUID()
        let createdAt = Date(timeIntervalSinceReferenceDate: 123)
        let preferences = BrowserProfile.DownloadPreferences(
            safeDownloadsOnly: false,
            revealInFinderWhenFinished: true
        )

        let profile = BrowserProfile(
            id: id,
            name: "Work",
            iconName: "briefcase.fill",
            createdAt: createdAt,
            downloadPreferences: preferences
        )

        #expect(profile.id == id)
        #expect(profile.name == "Work")
        #expect(profile.iconName == "briefcase.fill")
        #expect(profile.createdAt == createdAt)
        #expect(profile.downloadPreferences == preferences)
    }

    @Test func profileRoundTripsThroughJSON() throws {
        let profile = BrowserProfile(
            id: UUID(),
            name: "Research",
            iconName: "books.vertical.fill",
            createdAt: Date(timeIntervalSinceReferenceDate: 456),
            downloadPreferences: .init(safeDownloadsOnly: false, revealInFinderWhenFinished: true)
        )

        let decoded = try JSONDecoder().decode(BrowserProfile.self, from: JSONEncoder().encode(profile))

        #expect(decoded == profile)
    }

    @Test func legacyProfileWithoutIconUsesDefaultIcon() throws {
        let id = UUID()
        let data = try JSONSerialization.data(withJSONObject: ["id": id.uuidString, "name": "Legacy"])

        let profile = try JSONDecoder().decode(BrowserProfile.self, from: data)

        #expect(profile.id == id)
        #expect(profile.iconName == "person.crop.circle")
    }

    @Test func legacyProfileWithoutCreationDateUsesCurrentDate() throws {
        let before = Date()
        let data = try JSONSerialization.data(withJSONObject: ["id": UUID().uuidString, "name": "Legacy"])
        let profile = try JSONDecoder().decode(BrowserProfile.self, from: data)
        let after = Date()

        #expect(profile.createdAt >= before)
        #expect(profile.createdAt <= after)
    }

    @Test func legacyProfileWithoutDownloadPreferencesUsesSafeDefaults() throws {
        let data = try JSONSerialization.data(withJSONObject: ["id": UUID().uuidString, "name": "Legacy"])

        let profile = try JSONDecoder().decode(BrowserProfile.self, from: data)

        #expect(profile.downloadPreferences == .init())
    }

    @Test func deepLinkRejectsNonIlluminateScheme() {
        let request = BrowserWindowOpenRequest(url: URL(string: "https://new")!)

        #expect(request == nil)
    }

    @Test func deepLinkAcceptsCaseInsensitiveNewHost() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://NEW")!)

        #expect(request == .profileSelection)
    }

    @Test func profileDeepLinkRequiresProfileIdentifier() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://profile")!)

        #expect(request == nil)
    }

    @Test func profileDeepLinkRejectsEmptyProfileIdentifier() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://profile/")!)

        #expect(request == nil)
    }

    @Test func profileDeepLinkUsesFirstPathComponent() {
        let id = UUID()
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://profile/\(id.uuidString)/extra")!)

        #expect(request == .route(.profile(id)))
    }

    @Test func guestDeepLinkCreatesGuestRoute() {
        let request = BrowserWindowOpenRequest(url: URL(string: "illuminate://guest")!)

        guard case let .route(.guest(id))? = request else {
            Issue.record("Expected a guest route")
            return
        }
        #expect(id.uuidString.isEmpty == false)
    }

    @Test func profileAndGuestRoutesWithSameIdentifierAreDistinct() {
        let id = UUID()

        #expect(BrowserWindowRoute.profile(id) != .guest(id))
    }

    @Test func matchingRoutesAreEqualAndHashable() {
        let id = UUID()
        let routes: Set<BrowserWindowRoute> = [.profile(id), .profile(id), .guest(id), .guest(id)]

        #expect(routes.count == 2)
        #expect(BrowserWindowRoute.profile(id) == .profile(id))
        #expect(BrowserWindowRoute.guest(id) == .guest(id))
    }
}
