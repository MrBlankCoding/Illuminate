//
//  AsyncRequestDeduplicator.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/18/26.
//

import Foundation

actor AsyncRequestDeduplicator<Key: Hashable, Value> {
    private struct Entry {
        let token: UUID
        let task: Task<Value, Error>
    }

    private var tasks: [Key: Entry] = [:]

    func value(
        for key: Key,
        operation: @Sendable @escaping (Key) async throws -> Value
    ) async throws -> Value {
        if let entry = tasks[key] {
            return try await entry.task.value
        }

        let task = Task<Value, Error> { @Sendable in
            try await operation(key)
        }
        let token = UUID()
        tasks[key] = Entry(token: token, task: task)

        Task {
            _ = try? await task.value
            removeTask(for: key, token: token)
        }

        return try await task.value
    }

    private func removeTask(for key: Key, token: UUID) {
        guard tasks[key]?.token == token else {
            return
        }
        tasks[key] = nil
    }
}
