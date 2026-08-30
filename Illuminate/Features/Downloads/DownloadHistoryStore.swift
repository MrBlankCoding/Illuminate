//
//  DownloadHistoryStore.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class DownloadHistoryStore {
    private(set) var records: [DownloadRecord] = []

    let profileID: UUID?
    @ObservationIgnored private let isGuestSession: Bool
    @ObservationIgnored private let modelContainer: ModelContainer?

    @ObservationIgnored private var context: ModelContext?

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
        Task.detached(priority: .userInitiated) { [container, profileID] in
            let bgContext = ModelContext(container)
            bgContext.autosaveEnabled = false

            var fetch = FetchDescriptor<DownloadRecord>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            fetch.fetchLimit = 2000

            struct Snapshot {
                let id: UUID
                let profileID: UUID?
                let sourceURLString: String
                let filename: String
                let destinationPathString: String?
                let stateRawValue: String
                let createdAt: Date
                let finishedAt: Date?
                let bytesWritten: Int64
                let totalBytesExpected: Int64?
                let errorDescription: String?
                let resumeData: Data?
                let resumeRequiresWebKit: Bool
            }

            do {
                let fetched = try bgContext.fetch(fetch)
                let resumableStates: Set<String> = ["paused", "waitingToResume"]
                let snapshots = fetched.map { rec -> Snapshot in
                    let needsResume = resumableStates.contains(rec.stateRawValue)
                    return Snapshot(
                        id: rec.id,
                        profileID: rec.profileID,
                        sourceURLString: rec.sourceURLString,
                        filename: rec.filename,
                        destinationPathString: rec.destinationPathString,
                        stateRawValue: rec.stateRawValue,
                        createdAt: rec.createdAt,
                        finishedAt: rec.finishedAt,
                        bytesWritten: rec.bytesWritten,
                        totalBytesExpected: rec.totalBytesExpected,
                        errorDescription: rec.errorDescription,
                        resumeData: needsResume ? rec.resumeData : nil,
                        resumeRequiresWebKit: rec.resumeRequiresWebKit
                    )
                }

                await MainActor.run {
                    let filtered = snapshots.filter { $0.profileID == profileID }
                    if let ctx = self.context {
                        for record in self.records { ctx.delete(record) }
                    }
                    self.records = filtered.map {
                        DownloadRecord(
                            id: $0.id,
                            profileID: $0.profileID,
                            sourceURLString: $0.sourceURLString,
                            filename: $0.filename,
                            destinationPathString: $0.destinationPathString,
                            stateRawValue: $0.stateRawValue,
                            createdAt: $0.createdAt,
                            finishedAt: $0.finishedAt,
                            bytesWritten: $0.bytesWritten,
                            totalBytesExpected: $0.totalBytesExpected,
                            errorDescription: $0.errorDescription,
                            resumeData: $0.resumeData,
                            resumeRequiresWebKit: $0.resumeRequiresWebKit
                        )
                    }
                    self.records.forEach { self.context?.insert($0) }
                    AppLog.download("Loaded download history profile=\(profileID?.uuidString ?? "nil") count=\(self.records.count) totalInStore=\(snapshots.count)")
                }
            } catch {
                await MainActor.run {
                    AppLog.error("Failed to load download history", error: error)
                }
            }
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
