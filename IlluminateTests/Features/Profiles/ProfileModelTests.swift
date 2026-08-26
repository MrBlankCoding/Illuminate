//
//  ProfileModelTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate
struct ProfileModelTests {
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
}
