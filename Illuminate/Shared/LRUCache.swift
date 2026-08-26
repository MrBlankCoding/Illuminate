//
//  LRUCache.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation

final class LRUCache<Key: Hashable, Value> {
    private var store: [Key: Value] = [:]
    private var order: [Key] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    func value(for key: Key) -> Value? {
        guard let value = store[key] else { return nil }
        touch(key)
        return value
    }

    func insert(_ value: Value, for key: Key) {
        if store[key] != nil {
            store[key] = value
            touch(key)
            return
        }
        if store.count >= capacity {
            if let oldest = order.first {
                order.removeFirst()
                store.removeValue(forKey: oldest)
            }
        }
        store[key] = value
        order.append(key)
    }

    func removeValue(for key: Key) {
        guard store[key] != nil else { return }
        store.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }

    func removeAll() {
        store.removeAll()
        order.removeAll()
    }

    func removeAll(where predicate: (Value) -> Bool) {
        let keysToRemove = store.filter { predicate($0.value) }.map(\.key)
        for key in keysToRemove { removeValue(for: key) }
    }

    private func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}
