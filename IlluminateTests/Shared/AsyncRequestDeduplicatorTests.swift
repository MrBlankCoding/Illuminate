//
//  AsyncRequestDeduplicatorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

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

struct AsyncRequestDeduplicatorTests {
    @MainActor
@Test func coalescesConcurrentWork() async throws {
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
}
