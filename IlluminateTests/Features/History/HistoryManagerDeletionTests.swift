//
//  HistoryManagerDeletionTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import SwiftData
import Testing
@testable import Illuminate

@MainActor
struct HistoryManagerDeletionTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: HistoryEntry.self, configurations: config)
    }

    private func makeManager(container: ModelContainer) -> HistoryManager {
        HistoryManager(
            modelContainer: container,
            profileID: nil,
            isGuestSession: false,
            userDefaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        )
    }

    @discardableResult
    private func eventually(
        timeout: TimeInterval = 5,
        _ predicate: () async throws -> Bool
    ) async throws -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if try await predicate() { return true }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        return try await predicate()
    }

    @Test func deleteRemovesSingleEntryByID() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.record(url: URL(string: "https://keep.example.com")!, title: "Keep")
        try await Task.sleep(nanoseconds: 300_000_000)
        let entries = await manager.allEntries()

        for entry in entries where entry.urlString.contains("keep") {
            manager.delete(id: entry.id)
        }

        let emptied = try await eventually {
            await manager.allEntries().isEmpty
        }
        #expect(emptied)
    }

    @Test func clearAllEmptiesHistoryAndCaches() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.record(url: URL(string: "https://one.example.com")!, title: "One")
        manager.record(url: URL(string: "https://two.example.com")!, title: "Two")
        try await eventually { await manager.allEntries().count == 2 }

        manager.clearAll()
        let emptied = try await eventually { await manager.allEntries().isEmpty }
        #expect(emptied)
    }

    @Test func clearTodayRemovesRecentEntries() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.record(url: URL(string: "https://today.example.com")!, title: "Today")
        try await eventually { await manager.allEntries().count == 1 }

        manager.clearToday()
        let emptied = try await eventually { await manager.allEntries().isEmpty }
        #expect(emptied)
    }

    @Test func searchReturnsMatchingEntries() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.record(url: URL(string: "https://swift.example.com")!, title: "Swift Blog")
        manager.record(url: URL(string: "https://rust.example.com")!, title: "Rust News")
        try await eventually { await manager.allEntries().count == 2 }

        let hits = await manager.search(query: "SWIFT blog")
        #expect(hits.count == 1)
        #expect(hits.first?.urlString.contains("swift") == true)

        let blank = await manager.search(query: "")
        #expect(blank.count == 2)
    }

    @Test func prepareForRemovalIsSafeToCallRepeatedly() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.loadInitialData()
        manager.prepareForRemoval()
        manager.prepareForRemoval()

        let entries = await manager.allEntries()
        #expect(entries.isEmpty)
    }

    @Test func guestSessionLoadInitialDataDoesNothing() async throws {
        let container = try makeContainer()
        let manager = HistoryManager(
            modelContainer: container,
            profileID: nil,
            isGuestSession: true,
            userDefaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        )

        manager.loadInitialData()
        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(manager.recentEntries.isEmpty)
        #expect(manager.topSites.isEmpty)
    }

    @Test func deleteRemovesEntryImmediatelyFromInMemoryRecentEntries() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.record(url: URL(string: "https://item1.example.com")!, title: "Item 1")
        manager.record(url: URL(string: "https://item2.example.com")!, title: "Item 2")

        let populated = try await eventually {
            await manager.allEntries().count == 2
        }
        #expect(populated)

        manager.loadInitialData()
        let loaded = try await eventually {
            manager.recentEntries.count == 2
        }
        #expect(loaded)

        let targetEntry = manager.recentEntries.first { $0.urlString.contains("item1") }!
        manager.delete(id: targetEntry.id)

        #expect(!manager.recentEntries.contains { $0.id == targetEntry.id })
        #expect(manager.recentEntries.count == 1)

        let persistedEmpty = try await eventually {
            let entries = await manager.allEntries()
            return entries.count == 1 && !entries.contains { $0.id == targetEntry.id }
        }
        #expect(persistedEmpty)
    }

    @Test func deleteAllForHostRemovesMatchingHostEntries() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.record(url: URL(string: "https://apple.com/mac")!, title: "Mac")
        manager.record(url: URL(string: "https://apple.com/iphone")!, title: "iPhone")
        manager.record(url: URL(string: "https://google.com/search")!, title: "Google")

        try await eventually {
            await manager.allEntries().count == 3
        }

        manager.loadInitialData()
        try await eventually {
            manager.recentEntries.count == 3
        }

        manager.deleteAll(forHost: "apple.com")

        #expect(manager.recentEntries.allSatisfy { $0.url?.host != "apple.com" })
        #expect(manager.recentEntries.count == 1)

        let persistedDone = try await eventually {
            let entries = await manager.allEntries()
            return entries.count == 1 && entries.allSatisfy { $0.url?.host != "apple.com" }
        }
        #expect(persistedDone)
    }
}
