//
//  HistoryManagerSuggestionBehaviorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import SwiftData
import Testing
@testable import Illuminate

@MainActor
struct HistoryManagerSuggestionBehaviorTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: HistoryEntry.self, configurations: config)
    }

    private func makeManager(container: ModelContainer, isGuestSession: Bool = false) -> HistoryManager {
        let defaults = UserDefaults(suiteName: "history-suggestions-tests.\(UUID().uuidString)")!
        return HistoryManager(
            modelContainer: container,
            profileID: UUID(),
            isGuestSession: isGuestSession,
            userDefaults: defaults
        )
    }

    @discardableResult
    private func eventually(timeout: TimeInterval = 5, _ predicate: @escaping @MainActor () async -> Bool) async throws -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if await predicate() { return true }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        return await predicate()
    }

    @Test func searchQueriesIgnoreWhitespaceAndMatchUrlOrTitle() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        manager.record(url: URL(string: "https://alpha.example.com/docs")!, title: "Alpha Docs")

        let found = try await eventually {
            let results = await manager.search(query: "  alpha  ")
            return results.count == 1 && results.first?.displayTitle == "Alpha Docs"
        }

        #expect(found)
    }

    @Test func suggestionsOnlyReturnMatchingEntries() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        manager.record(url: URL(string: "https://alpha.example.com/docs")!, title: "Alpha Docs")
        manager.record(url: URL(string: "https://beta.example.com/other")!, title: "Beta")

        let matched = try await eventually {
            let suggestions = manager.suggestions(for: "alpha")
            return suggestions.count == 1 && suggestions.first?.urlString == "https://alpha.example.com/docs"
        }

        #expect(matched)
    }

    @Test func guestSessionDoesNotOfferHistorySuggestions() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container, isGuestSession: true)
        manager.record(url: URL(string: "https://private.example.com")!, title: "Private")

        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(manager.suggestions(for: "private").isEmpty)
        #expect(await manager.allEntries().isEmpty)
    }
}
