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

    @Test("missing key returns nil") func missingKey() {
        let cache = LRUCache<String, Int>(capacity: 4)
        #expect(cache.value(for: "absent") == nil)
    }

    @Test("zero capacity is clamped to one") func zeroCapacityClamped() {
        let cache = LRUCache<String, Int>(capacity: 0)
        cache.insert(1, for: "one")
        cache.insert(2, for: "two")
        #expect(cache.value(for: "one") == nil)
        #expect(cache.value(for: "two") == 2)
    }

    @Test("removeValue removes the entry") func removeValue() {
        let cache = LRUCache<String, Int>(capacity: 4)
        cache.insert(1, for: "one")
        cache.insert(2, for: "two")
        cache.removeValue(for: "one")
        #expect(cache.value(for: "one") == nil)
        #expect(cache.value(for: "two") == 2)
    }

    @Test("removeValue on missing key is a no-op") func removeMissing() {
        let cache = LRUCache<String, Int>(capacity: 2)
        cache.removeValue(for: "never-inserted")
    }

    @Test("removeAll clears the cache") func removeAllClears() {
        let cache = LRUCache<String, Int>(capacity: 4)
        cache.insert(1, for: "one")
        cache.insert(2, for: "two")
        cache.removeAll()
        #expect(cache.value(for: "one") == nil)
        #expect(cache.value(for: "two") == nil)
    }

    @Test("removing then reinserting works") func removeAndReinsert() {
        let cache = LRUCache<String, Int>(capacity: 2)
        cache.insert(1, for: "one")
        cache.insert(2, for: "two")
        cache.removeValue(for: "one")
        cache.insert(3, for: "three")
        #expect(cache.value(for: "two") == 2)
        #expect(cache.value(for: "three") == 3)
    }

    @Test("cache holds at most capacity entries") func capacityBound() {
        let cache = LRUCache<Int, Int>(capacity: 3)
        for i in 0..<10 { cache.insert(i, for: i) }
        #expect(cache.value(for: 0) == nil)
        #expect(cache.value(for: 9) == 9)
    }
}
