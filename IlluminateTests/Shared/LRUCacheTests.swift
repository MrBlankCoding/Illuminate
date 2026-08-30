//
//  LRUCacheTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 8/25/26.
//

import Foundation
import Testing
@testable import Illuminate

import Testing
import Foundation
import WebKit
@testable import Illuminate

final class LRUCacheTestHarness<Key: Hashable, Value> {
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
struct LRUCacheAlgorithmTests {

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
