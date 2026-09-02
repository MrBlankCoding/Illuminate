//
//  LRUCacheBehaviorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Testing
@testable import Illuminate

struct LRUCacheBehaviorTests {
    @Test func insertingPastCapacityEvictsLeastRecentlyUsedValue() {
        let cache = LRUCache<String, Int>(capacity: 2)
        cache.insert(1, for: "one")
        cache.insert(2, for: "two")
        _ = cache.value(for: "one")
        cache.insert(3, for: "three")

        #expect(cache.value(for: "one") == 1)
        #expect(cache.value(for: "two") == nil)
        #expect(cache.value(for: "three") == 3)
    }

    @Test func updatingExistingKeyRefreshesValueAndRecency() {
        let cache = LRUCache<String, Int>(capacity: 2)
        cache.insert(1, for: "one")
        cache.insert(2, for: "two")
        cache.insert(10, for: "one")
        cache.insert(3, for: "three")

        #expect(cache.value(for: "one") == 10)
        #expect(cache.value(for: "two") == nil)
    }

    @Test func removeAllWhereRemovesMatchingValuesOnly() {
        let cache = LRUCache<String, Int>(capacity: 4)
        cache.insert(1, for: "one")
        cache.insert(2, for: "two")
        cache.insert(3, for: "three")

        cache.removeAll { $0.isMultiple(of: 2) }

        #expect(cache.value(for: "one") == 1)
        #expect(cache.value(for: "two") == nil)
        #expect(cache.value(for: "three") == 3)
    }
}
