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

        // No crash and history still queryable afterwards.
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
}
