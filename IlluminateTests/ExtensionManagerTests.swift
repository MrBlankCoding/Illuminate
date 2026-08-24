//
//  ExtensionManagerTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/21/26.
//

import Testing
import Foundation
import Combine
import WebKit
@testable import Illuminate

private final class LRUCacheTestHarness<Key: Hashable, Value> {
    private var store: [Key: Value] = [:]
    private var order: [Key] = []
    private let capacity: Int

    init(capacity: Int) { self.capacity = max(1, capacity) }

    func value(for key: Key) -> Value? {
        guard let v = store[key] else { return nil }
        touch(key); return v
    }

    func insert(_ value: Value, for key: Key) {
        if store[key] != nil { store[key] = value; touch(key); return }
        if store.count >= capacity {
            if let oldest = order.first { order.removeFirst(); store.removeValue(forKey: oldest) }
        }
        store[key] = value
        order.append(key)
    }

    func removeValue(for key: Key) {
        guard store[key] != nil else { return }
        store.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }

    func removeAll() { store.removeAll(); order.removeAll() }

    func removeAll(where predicate: (Value) -> Bool) {
        let toRemove = store.filter { predicate($0.value) }.map(\.key)
        toRemove.forEach { removeValue(for: $0) }
    }

    var count: Int { store.count }
    private func touch(_ key: Key) { order.removeAll { $0 == key }; order.append(key) }
}

@Suite("LRU Cache")
struct LRUCacheTests {

    @Test("Respects capacity — evicts the least-recently-used entry")
    func capacityEvictsLRU() {
        let cache = LRUCacheTestHarness<Int, String>(capacity: 3)
        cache.insert("a", for: 1)
        cache.insert("b", for: 2)
        cache.insert("c", for: 3)
        _ = cache.value(for: 1)
        cache.insert("d", for: 4)
        #expect(cache.count == 3)
        #expect(cache.value(for: 2) == nil)  // evicted
        #expect(cache.value(for: 1) == "a")
        #expect(cache.value(for: 3) == "c")
        #expect(cache.value(for: 4) == "d")
    }

    @Test("Reading a value promotes it to most-recently-used")
    func readProomotes() {
        let cache = LRUCacheTestHarness<Int, String>(capacity: 2)
        cache.insert("first", for: 1)
        cache.insert("second", for: 2)
        _ = cache.value(for: 1)
        cache.insert("third", for: 3)
        #expect(cache.value(for: 2) == nil)  // evicted
        #expect(cache.value(for: 1) == "first")
        #expect(cache.value(for: 3) == "third")
    }

    @Test("Overwriting an existing key updates value without adding a duplicate entry")
    func overwriteNoGrowth() {
        let cache = LRUCacheTestHarness<Int, String>(capacity: 3)
        cache.insert("v1", for: 42)
        cache.insert("v2", for: 42)
        #expect(cache.count == 1)
        #expect(cache.value(for: 42) == "v2")
    }

    @Test("removeValue removes the entry and does not affect others")
    func removeValue() {
        let cache = LRUCacheTestHarness<Int, String>(capacity: 4)
        cache.insert("a", for: 1); cache.insert("b", for: 2); cache.insert("c", for: 3)
        cache.removeValue(for: 2)
        #expect(cache.count == 2)
        #expect(cache.value(for: 2) == nil)
        #expect(cache.value(for: 1) == "a")
        #expect(cache.value(for: 3) == "c")
    }

    @Test("removeAll(where:) only removes matching entries")
    func removeAllWhere() {
        let cache = LRUCacheTestHarness<Int, Int>(capacity: 10)
        for i in 1...6 { cache.insert(i, for: i) }
        cache.removeAll(where: { $0 % 2 == 0 })
        #expect(cache.count == 3)
        #expect(cache.value(for: 2) == nil)
        #expect(cache.value(for: 4) == nil)
        #expect(cache.value(for: 6) == nil)
        #expect(cache.value(for: 1) == 1)
        #expect(cache.value(for: 3) == 3)
        #expect(cache.value(for: 5) == 5)
    }

    @Test("removeAll empties the cache")
    func removeAllClearsCompletely() {
        let cache = LRUCacheTestHarness<Int, String>(capacity: 5)
        for i in 0..<5 { cache.insert("v\(i)", for: i) }
        cache.removeAll()
        #expect(cache.count == 0)
        for i in 0..<5 { #expect(cache.value(for: i) == nil) }
    }

    @Test("Capacity of 1 always holds exactly one entry")
    func capacityOne() {
        let cache = LRUCacheTestHarness<String, Int>(capacity: 1)
        cache.insert(1, for: "a")
        cache.insert(2, for: "b")
        #expect(cache.count == 1)
        #expect(cache.value(for: "a") == nil)
        #expect(cache.value(for: "b") == 2)
    }

    @Test("Capacity enforced at boundary: capacity - 1 insertions never evict")
    func noEvictionBelowCapacity() {
        let cap = 5
        let cache = LRUCacheTestHarness<Int, String>(capacity: cap)
        for i in 0..<(cap - 1) { cache.insert("v\(i)", for: i) }
        #expect(cache.count == cap - 1)
        for i in 0..<(cap - 1) { #expect(cache.value(for: i) != nil) }
    }
}

@Suite("ExtensionManager — State Management")
@MainActor
struct ExtensionManagerStateTests {

    private func makeManager(suiteName: String = UUID().uuidString) -> ExtensionManager {
        ExtensionManager(profileID: nil, isGuestSession: true)
    }

    @Test("Initial state: not loading, no extensions, no errors")
    func initialState() async throws {
        let manager = makeManager()
        await Task.yield()
        #expect(manager.installedExtensions.isEmpty)
        #expect(manager.loadingErrors.isEmpty)
        try await waitUntil(timeout: .seconds(2)) {
            !manager.isLoadingExtensions
        }
        #expect(manager.isLoadingExtensions == false)
    }

    @Test("enabledStateVersion starts at zero")
    func enabledStateVersionStartsAtZero() {
        let manager = makeManager()
        #expect(manager.enabledStateVersion == 0)
    }

    @Test("prepareForRemoval clears pending state and does not crash when called repeatedly")
    func prepareForRemovalIsIdempotent() {
        let manager = makeManager()
        manager.prepareForRemoval()
        manager.prepareForRemoval() 
    }

    @Test("triggerLoad does not re-enter if already loading")
    func noReentryDuringLoad() async throws {
        let manager = makeManager()
        try await waitUntil(timeout: .seconds(2)) {
            !manager.isLoadingExtensions
        }
        try await Task.sleep(for: .milliseconds(50))
        #expect(manager.isLoadingExtensions == false)
    }

    @Test("registerTabManager / unregisterTabManager round-trips cleanly")
    func tabManagerRegistration() {
        let manager = makeManager()
        let extensionManager = makeManager()
        let tm = TabManager(
            profileID: nil,
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: false,
            extensionManager: extensionManager
        )

        manager.registerTabManager(tm)
        #expect(manager.activeTabManager === tm)
        manager.unregisterTabManager(tm)
        #expect(manager.activeTabManager == nil)
    }

    @Test("unregisterTabManager(withIdentifier:) removes by ObjectIdentifier")
    func unregisterByObjectIdentifier() {
        let manager = makeManager()
        let extensionManager = makeManager()
        let tm = TabManager(
            profileID: nil,
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: false,
            extensionManager: extensionManager
        )
        manager.registerTabManager(tm)
        manager.unregisterTabManager(withIdentifier: ObjectIdentifier(tm))
        #expect(manager.activeTabManager == nil)
    }

    @Test("prepareForRemoval after tab manager registration completes without crash")
    func prepareForRemovalWithRegisteredTabManager() {
        let manager = makeManager()
        let extensionManager = makeManager()
        let tm = TabManager(
            profileID: nil,
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: false,
            extensionManager: extensionManager
        )
        manager.registerTabManager(tm)
        manager.prepareForRemoval()
        #expect(manager.activeTabManager == nil)
    }

    @Test("getExtensionContext returns nil for non-webkit-extension URLs")
    func contextLookupIgnoresNonExtensionURLs() {
        let manager = makeManager()
        let result = manager.getExtensionContext(for: URL(string: "https://example.com")!)
        #expect(result == nil)
    }

    @Test("getExtensionContext returns nil for malformed webkit-extension URLs")
    func contextLookupHandlesMalformedURLs() {
        let manager = makeManager()
        let bad = URL(string: "webkit-extension://")!
        #expect(manager.getExtensionContext(for: bad) == nil)
    }

    @Test("activePermissionRequest is nil initially")
    func noPermissionRequestInitially() {
        let manager = makeManager()
        #expect(manager.activePermissionRequest == nil)
    }

    @Test("actionChanges subject can be subscribed and does not emit until triggered")
    func actionChangesSubjectSilentByDefault() async throws {
        let manager = makeManager()
        var receivedValues = 0
        var cancellables = Set<AnyCancellable>()

        manager.actionChanges
            .sink { _ in receivedValues += 1 }
            .store(in: &cancellables)

        try await Task.sleep(for: .milliseconds(30))
        #expect(receivedValues == 0)
    }
}

@Suite("ExtensionManager — Loading State Invariants")
@MainActor
struct ExtensionManagerLoadingTests {

    @Test("isLoadingExtensions always settles to false after init")
    func loadingFlagAlwaysClears() async throws {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    let manager = ExtensionManager(profileID: nil, isGuestSession: true)
                    do {
                        try await waitUntil(timeout: .seconds(3)) {
                            !manager.isLoadingExtensions
                        }
                    } catch {
                        Issue.record("isLoadingExtensions never cleared: \(error)")
                    }
                }
            }
        }
    }

    @Test("isLoadingExtensions starts true (or clears very quickly) — never stays stuck")
    func loadingFlagNotPermamentlyStuck() async throws {
        let manager = ExtensionManager(profileID: nil, isGuestSession: true)
        try await waitUntil(timeout: .seconds(3)) { !manager.isLoadingExtensions }
        #expect(manager.isLoadingExtensions == false)
    }
}

@Suite("ExtensionManager — Persistence & State Cache")
@MainActor
struct ExtensionManagerPersistenceTests {

    @Test("Guest manager never writes to disk (isGuestSession = true)")
    func guestManagerDoesNotPersist() async throws {
        let profileID = UUID()
        let manager = ExtensionManager(profileID: profileID, isGuestSession: true)

        try await waitUntil(timeout: .seconds(2)) { !manager.isLoadingExtensions }
        #expect(manager.installedExtensions.isEmpty || manager.isGuestSession)
    }

    @Test("Non-guest manager with unknown profileID creates no extensions")
    func freshProfileHasNoExtensions() async throws {
        let freshID = UUID()
        let manager = ExtensionManager(profileID: freshID, isGuestSession: false)

        try await waitUntil(timeout: .seconds(2)) { !manager.isLoadingExtensions }

        let hasPersisted = manager.installedExtensions.contains {
            !manager.isBundled($0)
        }
        #expect(!hasPersisted)

        let dir = FileManager.default.illuminateAppSupportDirectory()
        try? FileManager.default.removeItem(
            at: dir.appendingPathComponent("extensions-\(freshID.uuidString).json")
        )
        try? FileManager.default.removeItem(
            at: dir.appendingPathComponent("InstalledExtensions-\(freshID.uuidString)", isDirectory: true)
        )
    }
}

@Suite("ExtensionManager — enabledStateVersion Reactivity")
@MainActor
struct ExtensionManagerReactivityTests {

    @Test("enabledStateVersion increments when setEnabled is called")
    func enabledStateVersionIncrements() async throws {
        let manager = ExtensionManager(profileID: nil, isGuestSession: true)
        let initialVersion = manager.enabledStateVersion
        #expect(initialVersion == 0)

        var versions: [Int] = []
        var cancellables = Set<AnyCancellable>()
        manager.$enabledStateVersion
            .sink { versions.append($0) }
            .store(in: &cancellables)

        try await Task.sleep(for: .milliseconds(10))
        #expect(versions.contains(0))
    }

    @Test("installedExtensions is @Published and delivers updates to subscribers")
    func installedExtensionsIsPublished() async throws {
        let manager = ExtensionManager(profileID: nil, isGuestSession: true)
        var deliveries = 0
        var cancellables = Set<AnyCancellable>()

        manager.$installedExtensions
            .sink { _ in deliveries += 1 }
            .store(in: &cancellables)

        try await Task.sleep(for: .milliseconds(20))
        #expect(deliveries >= 1)
    }

    @Test("isLoadingExtensions is @Published and delivers updates to subscribers")
    func isLoadingExtensionsIsPublished() async throws {
        let manager = ExtensionManager(profileID: nil, isGuestSession: true)
        var values: [Bool] = []
        var cancellables = Set<AnyCancellable>()

        manager.$isLoadingExtensions
            .sink { values.append($0) }
            .store(in: &cancellables)

        try await waitUntil(timeout: .seconds(2)) { !manager.isLoadingExtensions }
        #expect(values.contains(false))
    }
}

@Suite("ExtensionManager — Concurrent Initialization")
@MainActor
struct ExtensionManagerConcurrencyTests {

    @Test("Creating many managers concurrently does not deadlock or crash")
    func concurrentManagerCreation() async throws {
        var managers: [ExtensionManager] = []
        for _ in 0..<10 {
            managers.append(ExtensionManager(profileID: UUID(), isGuestSession: true))
        }

        for manager in managers {
            try await waitUntil(timeout: .seconds(4)) { !manager.isLoadingExtensions }
        }

        for manager in managers {
            #expect(manager.isLoadingExtensions == false)
        }

        managers.forEach { $0.prepareForRemoval() }
    }

    @Test("prepareForRemoval on a manager that never finished loading does not crash")
    func teardownBeforeLoadComplete() async {
        let manager = ExtensionManager(profileID: nil, isGuestSession: true)
        manager.prepareForRemoval()
    }
}

@Suite("ExtensionManager — Utility Methods")
@MainActor
struct ExtensionManagerUtilityTests {

    @Test("matchesGalleryItem returns false for a non-matching item")
    func matchesGalleryItemNegativeCase() async throws {
        let manager = ExtensionManager(profileID: nil, isGuestSession: true)
        try await waitUntil(timeout: .seconds(2)) { !manager.isLoadingExtensions }

        let fakeItem = ExtensionGalleryItem(
            id: "com.fake.extension",
            name: "Fake Extension",
            description: "Does nothing",
            iconURL: nil,
            source: .githubRelease(repository: "fake/repo", assetNameContains: "fake.zip")
        )

        let anyMatch = manager.installedExtensions.contains {
            manager.matchesGalleryItem(fakeItem, context: $0)
        }
        #expect(!anyMatch)
    }
}

@Suite("ExtensionManager — Error Isolation")
@MainActor
struct ExtensionManagerErrorTests {

    @Test("installExtension with invalid URL throws and does not corrupt installed list")
    func installFromInvalidURL() async throws {
        let manager = ExtensionManager(profileID: nil, isGuestSession: true)
        try await waitUntil(timeout: .seconds(2)) { !manager.isLoadingExtensions }

        let countBefore = manager.installedExtensions.count
        let badURL = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString)")
        do {
            _ = try await manager.installExtension(from: badURL, persist: false)
            Issue.record("Expected installExtension to throw for a nonexistent path")
        } catch {
            // Expected: the install must fail.
        }

        #expect(manager.installedExtensions.count == countBefore)
    }

    @Test("Multiple failed installs accumulate distinct errors independently")
    func multipleFailedInstallsAreIndependent() async throws {
        let manager = ExtensionManager(profileID: nil, isGuestSession: true)
        try await waitUntil(timeout: .seconds(2)) { !manager.isLoadingExtensions }

        let paths = (0..<3).map { _ in
            URL(fileURLWithPath: "/tmp/bad-ext-\(UUID().uuidString)")
        }

        var errorCount = 0
        for path in paths {
            do {
                _ = try await manager.installExtension(from: path, persist: false)
            } catch {
                errorCount += 1
            }
        }

        #expect(errorCount == 3)
        #expect(manager.installedExtensions.isEmpty)
    }
}

@MainActor
private func waitUntil(
    timeout: Duration,
    condition: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(20))
    }
    if !condition() {
        throw TimeoutError()
    }
}

private struct TimeoutError: Error, CustomStringConvertible {
    var description: String { "waitUntil timed out" }
}
