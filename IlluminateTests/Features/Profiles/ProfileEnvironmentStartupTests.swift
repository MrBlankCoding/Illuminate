//
//  ProfileEnvironmentStartupTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/1/26.
//

import Foundation
import SwiftData
import Testing
@testable import Illuminate

@MainActor
struct ProfileEnvironmentStartupTests {
    private func createInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Password.self, Bookmark.self,
            configurations: config
        )
    }

    @Test func testStartupServicesInitializeLazily() async throws {
        let container = try createInMemoryContainer()
        let env = ProfileEnvironment(
            profile: BrowserProfile(name: "Launch Test"),
            modelContainer: container
        )

        #expect(env.hasLazyServicesLoaded == false)

        _ = env.passwordService
        _ = env.webKitManager
        _ = env.trackerBlockingService

        #expect(env.hasLazyServicesLoaded == true)
    }
}
