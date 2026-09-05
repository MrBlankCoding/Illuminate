//
//  HistoryManagerLogicTests.swift
//  IlluminateTests
//

import Testing
import Foundation
@testable import Illuminate
import SwiftData
import AppKit

@MainActor
struct HistoryManagerLogicTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: HistoryEntry.self, configurations: config)
    }

    private func makeManager(
        container: ModelContainer,
        profileID: UUID? = nil,
        isGuestSession: Bool = false
    ) -> HistoryManager {
        // Ephemeral defaults so preference writes from one test never leak
        // into another (isSavingEnabled didSet persists immediately).
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return HistoryManager(
            modelContainer: container,
            profileID: profileID,
            isGuestSession: isGuestSession,
            userDefaults: defaults
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

    @Test func recordPersistsEntryAndDeduplicatesByURL() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        let url = URL(string: "https://example.com/page")!

        manager.record(url: url, title: "Example")
        let recorded = try await eventually {
            await manager.allEntries().count == 1
        }
        #expect(recorded)

        manager.record(url: url, title: "Example Updated")
        let updated = try await eventually {
            let entries = await manager.allEntries()
            return entries.count == 1 && entries.first?.visitCount == 2
                && entries.first?.title == "Example Updated"
        }
        #expect(updated)
    }

    @Test func guestSessionNeverRecords() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container, isGuestSession: true)

        manager.record(url: URL(string: "https://example.com/private")!, title: "Private")
        try await Task.sleep(nanoseconds: 800_000_000)

        let entries = await manager.allEntries()
        #expect(entries.isEmpty)
    }

    @Test func disabledSavingNeverRecords() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        manager.isSavingEnabled = false

        manager.record(url: URL(string: "https://example.com/nope")!, title: "Nope")
        try await Task.sleep(nanoseconds: 800_000_000)

        let entries = await manager.allEntries()
        #expect(entries.isEmpty)
    }

    @Test func nonWebSchemesAreNotRecorded() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.record(url: URL(string: "illuminate://history")!, title: "Internal")
        manager.record(url: URL(string: "about:blank")!, title: "Blank")
        manager.record(url: URL(string: "webkit-extension://abc/page")!, title: "Extension")
        manager.record(url: URL(string: "ftp://files.example.com/file")!, title: "FTP")
        try await Task.sleep(nanoseconds: 200_000_000)

        let entries = await manager.allEntries()
        #expect(entries.isEmpty)
    }

    @Test func sameTabSameURLIsRecordedOnce() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        let url = URL(string: "https://example.com/same")!
        let tabID = UUID()

        manager.record(url: url, title: "One", tabID: tabID)
        manager.record(url: url, title: "Two", tabID: tabID)
        manager.record(url: url, title: "Three", tabID: UUID())

        let settled = try await eventually {
            await manager.allEntries().count == 1
        }
        #expect(settled)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(await manager.allEntries().count == 1)
    }

    @Test func invalidateTabCacheAllowsReRecording() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        let url = URL(string: "https://example.com/cache")!
        let tabID = UUID()

        manager.record(url: url, title: "First", tabID: tabID)
        let firstRecorded = try await eventually {
            await manager.allEntries().count == 1
        }
        #expect(firstRecorded)

        manager.invalidateTabCache(tabID: tabID)
        manager.record(url: url, title: "Second", tabID: tabID)

        let bumped = try await eventually {
            let entries = await manager.allEntries()
            return entries.count == 1 && entries.first?.visitCount == 2
        }
        #expect(bumped)
    }

    @Test func updateMetadataChangesTitle() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        let url = URL(string: "https://example.com/meta")!

        manager.record(url: url, title: "Before")
        let recorded = try await eventually {
            await manager.allEntries().count == 1
        }
        #expect(recorded)

        manager.updateMetadata(for: url, title: "After")
        let updated = try await eventually {
            await manager.allEntries().first?.title == "After"
        }
        #expect(updated)
    }

    @Test func emptyTitleFallsBackToHost() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        let url = URL(string: "https://fallback.example.com/deep/path")!

        manager.record(url: url, title: "   ")
        let settled = try await eventually {
            await manager.allEntries().first?.displayTitle == "fallback.example.com"
        }
        #expect(settled)
    }

    @Test func suggestionsRankByVisitCountAndTitlePrefix() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.record(url: URL(string: "https://low.example.com/article")!, title: "Article")
        let lowRecorded = try await eventually {
            await manager.allEntries().count == 1
        }
        #expect(lowRecorded)

        for _ in 0..<5 {
            manager.record(url: URL(string: "https://high.example.com")!, title: "Homepage")
        }
        let highBumped = try await eventually {
            let entries = await manager.allEntries()
            return entries.count == 2
                && entries.first(where: { $0.urlString.contains("high") })?.visitCount == 5
        }
        #expect(highBumped)

        // Suggestion candidates are rebuilt on a debounce after each record,
        // so poll until the ranked suggestions reflect the stored history.
        let ranked = try await eventually {
            let results = manager.suggestions(for: "exam")
            guard results.count == 2 else { return false }
            return results.first?.urlString.contains("high") == true
                && Set(results.map(\.urlString)).count == 2
        }
        #expect(ranked)
    }

    @Test func suggestionsEmptyForBlankQuery() throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        #expect(manager.suggestions(for: "").isEmpty)
        #expect(manager.suggestions(for: "   ").isEmpty)
    }

    @Test func suggestionsRespectLimit() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        for i in 0..<4 {
            manager.record(url: URL(string: "https://site\(i).example.com/doc\(i)")!, title: "Doc \(i)")
        }
        let allRecorded = try await eventually {
            await manager.allEntries().count == 4
        }
        #expect(allRecorded)

        let limited = try await eventually {
            manager.suggestions(for: "doc", limit: 2).count == 2
        }
        #expect(limited)
    }

    @Test func suggestionsDisabledWhenToggleOff() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        manager.showHistorySuggestions = false

        manager.record(url: URL(string: "https://example.com/hidden")!, title: "Hidden")
        let recorded = try await eventually {
            await manager.allEntries().count == 1
        }
        #expect(recorded)

        #expect(manager.suggestions(for: "hidden").isEmpty)
    }

    @Test func deleteAllForHostRemovesOnlyThatHost() async throws {
        let container = try makeContainer()
        let actor = HistoryModelActor(modelContainer: container)

        await actor.record(urlString: "https://a.example.com/one", title: "One", faviconURLString: nil)
        await actor.record(urlString: "https://a.example.com/two", title: "Two", faviconURLString: nil)
        await actor.record(urlString: "https://b.example.com/three", title: "Three", faviconURLString: nil)

        await actor.deleteAll(forHost: "a.example.com")

        let remaining = await actor.fetchRecentEntries(limit: 100)
        #expect(remaining.count == 1)
        #expect(remaining.first?.urlString == "https://b.example.com/three")
    }

    @Test func clearHistorySinceRemovesNewerEntriesOnly() async throws {
        let container = try makeContainer()
        let actor = HistoryModelActor(modelContainer: container)

        let old = Date().addingTimeInterval(-86_400 * 10)
        await actor.record(urlString: "https://old.example.com", title: "Old", faviconURLString: nil)
        await actor.record(urlString: "https://new.example.com", title: "New", faviconURLString: nil)

        let all = await actor.fetchRecentEntries(limit: 100)
        if let oldEntry = all.first(where: { $0.urlString == "https://old.example.com" }) {
            oldEntry.lastVisited = old
            try container.mainContext.save()
        }

        await actor.clearHistory(since: Date().addingTimeInterval(-3_600))

        let remaining = await actor.fetchRecentEntries(limit: 100)
        #expect(remaining.count == 1)
        #expect(remaining.first?.urlString == "https://old.example.com")
    }

    @Test func clearAllRemovesEverything() async throws {
        let container = try makeContainer()
        let actor = HistoryModelActor(modelContainer: container)

        await actor.record(urlString: "https://one.example.com", title: "One", faviconURLString: nil)
        await actor.record(urlString: "https://two.example.com", title: "Two", faviconURLString: nil)
        await actor.clearAll()

        let remaining = await actor.fetchRecentEntries(limit: 100)
        #expect(remaining.isEmpty)
    }

    @Test func searchFiltersByTitleAndURL() async throws {
        let container = try makeContainer()
        let actor = HistoryModelActor(modelContainer: container)

        await actor.record(urlString: "https://swift.org/blog/swift-6", title: "Swift 6 Release", faviconURLString: nil)
        await actor.record(urlString: "https://rust-lang.org", title: "Rust", faviconURLString: nil)

        let byTitle = await actor.search(query: "swift 6 rel", limit: 10)
        #expect(byTitle.count == 1)
        #expect(byTitle.first?.urlString == "https://swift.org/blog/swift-6")

        let byURL = await actor.search(query: "rust-lang", limit: 10)
        #expect(byURL.count == 1)
    }

    @Test func fetchTopSitesReturnsUniqueHosts() async throws {
        let container = try makeContainer()
        let actor = HistoryModelActor(modelContainer: container)

        for _ in 0..<3 {
            await actor.record(urlString: "https://www.popularsite.com/a", title: "A", faviconURLString: nil)
        }
        await actor.record(urlString: "https://popularsite.com/b", title: "B", faviconURLString: nil)
        await actor.record(urlString: "https://otherdomain.org/c", title: "C", faviconURLString: nil)

        let top = await actor.fetchTopSites(limit: 8)
        let keys = top.map { $0.url?.eTLDPlusOne ?? $0.url?.host ?? "" }
        #expect(Set(keys).count == keys.count)
        #expect(top.count == 2)
        #expect(keys.contains("popularsite.com"))
        #expect(keys.contains("otherdomain.org"))
    }

    @Test func recencyLabelUsesHumanFriendlyRanges() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        let monthAgo = Calendar.current.date(byAdding: .day, value: -40, to: today)!

        func label(for date: Date) -> String {
            HistorySuggestion(
                id: UUID(), title: "t", urlString: "https://e.com",
                visitCount: 1, lastVisited: date, faviconURL: nil
            ).recencyLabel
        }

        #expect(label(for: today) == "Visited today")
        #expect(label(for: yesterday) == "Visited yesterday")
        #expect(label(for: threeDaysAgo) == "Visited 3 days ago")
        #expect(!label(for: monthAgo).hasPrefix("Visited \(monthAgo.formatted())"))
        #expect(label(for: monthAgo).contains("Visited"))
    }

    @Test func clearingHistoryThroughManagerRefreshesSuggestionCandidates() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        manager.record(url: URL(string: "https://clear.example/page")!, title: "Clear Me")

        let recorded = try await eventually {
            manager.suggestions(for: "clear").count == 1
        }
        #expect(recorded)

        manager.clearAll()
        let cleared = try await eventually {
            let suggestionsEmpty = manager.suggestions(for: "clear").isEmpty
            let entriesEmpty = await manager.allEntries().isEmpty
            return suggestionsEmpty && entriesEmpty
        }

        #expect(cleared)
    }

    @Test func searchWithBlankQueryReturnsAllEntriesInRecentOrder() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        manager.record(url: URL(string: "https://one.example")!, title: "One")
        manager.record(url: URL(string: "https://two.example")!, title: "Two")

        let settled = try await eventually {
            await manager.allEntries().count == 2
        }
        #expect(settled)

        let results = await manager.search(query: "   ")
        #expect(results.count == 2)
        #expect(results.first?.lastVisited ?? .distantPast >= results.last?.lastVisited ?? .distantPast)
    }

    @Test func disablingSavingClearsOnlyFutureWrites() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        manager.record(url: URL(string: "https://saved.example")!, title: "Saved")

        let recorded = try await eventually {
            await manager.allEntries().count == 1
        }
        #expect(recorded)

        manager.isSavingEnabled = false
        manager.record(url: URL(string: "https://ignored.example")!, title: "Ignored")
        try await Task.sleep(nanoseconds: 500_000_000)

        let entries = await manager.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.urlString == "https://saved.example")
    }

    @Test func recentSearchQueriesExtractsTypedSearchesFromHistory() async throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)
        manager.record(url: URL(string: "https://www.google.com/search?q=cats%20dogs")!, title: "cats dogs - Google")
        manager.record(url: URL(string: "https://www.bing.com/search?q=swift%20ui")!, title: "swift ui - Bing")
        manager.record(url: URL(string: "https://www.google.com/search?q=cats%20dogs")!, title: "cats dogs - Google (again)")
        manager.record(url: URL(string: "https://example.com/article")!, title: "Article")

        var result: [String] = []
        let found = try await eventually {
            result = manager.recentSearchQueries(limit: 5)
            return result.count == 2 && Set(result) == Set(["cats dogs", "swift ui"])
        }
        #expect(found)
    }
}
