//
//  DownloadHistoryStore.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class DownloadHistoryStore: ObservableObject {
    @Published private(set) var records: [DownloadRecord] = []

    let profileID: UUID?
    private let isGuestSession: Bool
    private let modelContainer: ModelContainer?

    private var context: ModelContext?

    init(
        profileID: UUID?,
        isGuestSession: Bool,
        modelContainer: ModelContainer?
    ) {
        self.profileID = profileID
        self.isGuestSession = isGuestSession
        self.modelContainer = isGuestSession ? nil : modelContainer

        if !isGuestSession {
            loadRecords()
        }
    }

    func record(_ task: DownloadTask) {
        if let index = records.firstIndex(where: { $0.id == task.id }) {
            let record = records[index]
            record.apply(task)
            save()
        } else {
            let record = DownloadRecord(task: task, profileID: profileID)
            records.insert(record, at: 0)
            insertPersisted(record)
        }
    }

    func remove(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let record = records.remove(at: index)
        deletePersisted(record)
    }

    func clearAll() {
        records.forEach(deletePersisted)
        records.removeAll()
    }

    func contains(id: UUID) -> Bool {
        records.contains(where: { $0.id == id })
    }

    private func loadRecords() {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.context = context

        var fetch = FetchDescriptor<DownloadRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        fetch.fetchLimit = 2000

        do {
            let allRecords = try context.fetch(fetch)
            records = allRecords.filter { $0.profileID == profileID }
            AppLog.download("Loaded download history profile=\(profileID?.uuidString ?? "nil") count=\(records.count) totalInStore=\(allRecords.count)")
        } catch {
            AppLog.error("Failed to load download history", error: error)
        }
    }

    private func insertPersisted(_ record: DownloadRecord) {
        guard let context else { return }
        context.insert(record)
        save()
    }

    private func deletePersisted(_ record: DownloadRecord) {
        guard let context else { return }
        context.delete(record)
        save()
    }

    private func save() {
        guard let context else { return }
        do {
            try context.save()
        } catch {
            AppLog.error("Failed to persist download history", error: error)
        }
    }
}

@MainActor
final class DownloadHistoryRegistry {
    static let shared = DownloadHistoryRegistry()

    private final class WeakStore {
        weak var store: DownloadHistoryStore?
        init(_ store: DownloadHistoryStore) { self.store = store }
    }

    private var stores: [UUID: WeakStore] = [:]

    func register(_ store: DownloadHistoryStore) {
        guard let key = store.profileID else { return }
        stores[key] = WeakStore(store)
    }

    func unregister(_ store: DownloadHistoryStore) {
        guard let key = store.profileID, stores[key]?.store === store || stores[key]?.store == nil else { return }
        stores.removeValue(forKey: key)
    }

    func store(for profileID: UUID) -> DownloadHistoryStore? {
        stores[profileID]?.store
    }
}
