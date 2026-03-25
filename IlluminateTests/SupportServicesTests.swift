//
//  SupportServicesTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/18/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Illuminate

struct SupportServicesTests {

    @Test func safeBrowsingBlocksKnownHostsOnly() {
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://malware.test/path")!) == true)
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://PHISHING.TEST")!) == true)
        #expect(SafeBrowsingManager.isUnsafe(URL(string: "https://example.com")!) == false)
        #expect(SafeBrowsingManager.isUnsafe(URL(fileURLWithPath: "/tmp/file")) == false)
    }

    @Test func circuitBreakerStopsAfterConfiguredBurstAndResets() {
        let breaker = WebProcessCircuitBreaker(maxReloads: 2, cooldown: 60)

        #expect(breaker.canReloadAfterTermination() == true)
        #expect(breaker.canReloadAfterTermination() == true)
        #expect(breaker.canReloadAfterTermination() == false)

        breaker.reset()

        #expect(breaker.canReloadAfterTermination() == true)
    }

    @Test func safeNumericConversionsUseFallbackForInvalidValues() {
        #expect(SafeNumericConversions.int(from: 1.6) == 2)
        #expect(SafeNumericConversions.int(from: .infinity, fallback: 9) == 9)
        #expect(SafeNumericConversions.cgFloat(from: .nan, fallback: 7) == 7)

        let size = SafeNumericConversions.cgSize(width: 10, height: 5)
        #expect(size == CGSize(width: 10, height: 5))

        let fallback = CGSize(width: 3, height: 4)
        #expect(SafeNumericConversions.cgSize(width: .nan, height: 1, fallback: fallback) == fallback)
    }

    @Test func asyncRequestDeduplicatorCoalescesConcurrentWork() async throws {
        let deduplicator = AsyncRequestDeduplicator<String, Int>()
        let counter = LockedCounter()

        async let first = deduplicator.value(for: "same-key") { _ in
            counter.increment()
            try await Task.sleep(nanoseconds: 100_000_000)
            return 42
        }
        async let second = deduplicator.value(for: "same-key") { _ in
            counter.increment()
            return 7
        }

        let firstValue = try await first
        let secondValue = try await second

        #expect(firstValue == secondValue)
        #expect([42, 7].contains(firstValue))
        #expect(counter.value == 1)
    }

    @MainActor
    @Test func urlSynchronizerPublishesUpdatedURL() async throws {
        let synchronizer = URLSynchronizer.shared
        let firstURL = URL(string: "https://first.example")!
        let secondURL = URL(string: "https://second.example")!

        synchronizer.updateCurrentURL(nil)
        synchronizer.updateCurrentURL(firstURL)
        #expect(synchronizer.currentURL == firstURL)

        synchronizer.updateCurrentURL(secondURL)
        #expect(synchronizer.currentURL == secondURL)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
