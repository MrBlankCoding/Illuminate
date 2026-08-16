//
//  HistoryManager.swift
//  Illuminate
//
//  Created by Illuminate on 8/10/26.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

struct HistorySuggestion: Identifiable, Equatable {
    let id: UUID
    let title: String
    let urlString: String
    let visitCount: Int
    let lastVisited: Date
    let faviconURL: URL?

    var url: URL? { URL(string: urlString) }
    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var recencyLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(lastVisited) { return "Visited today" }
        if cal.isDateInYesterday(lastVisited) { return "Visited yesterday" }
        let days = cal.dateComponents([.day], from: lastVisited, to: Date()).day ?? 0
        if days <= 7 { return "Visited \(days) day\(days == 1 ? "" : "s") ago" }
        return "Visited \(Self.mediumDateFormatter.string(from: lastVisited))"
    }
}

@MainActor
final class HistoryManager: ObservableObject {
    @Published private(set) var recentEntries: [HistoryEntry] = []
    @Published private(set) var topSites: [HistoryEntry] = []

    @Published var isSavingEnabled: Bool {
        didSet { 
            AppLog.info("HistoryManager: Setting changed isSavingEnabled=\(isSavingEnabled)")
            persist(isSavingEnabled, forKey: settingsKey("historySavingEnabled")) 
        }
    }

    @Published var showTopSites: Bool {
        didSet { persist(showTopSites, forKey: settingsKey("historyShowTopSites")) }
    }

    @Published var showHistorySuggestions: Bool {
        didSet { persist(showHistorySuggestions, forKey: settingsKey("historyShowSuggestions")) }
    }

    private let modelContext: ModelContext
    private let profileID: UUID?
    private let isGuestSession: Bool
    private let userDefaults: UserDefaults
    private var lastRecordedURL: [UUID: String] = [:]
    private var pendingRefreshTask: Task<Void, Never>?
    private static let refreshDebounceNs: UInt64 = 300_000_000 // 300 ms
    private static let suggestionsFetchLimit = 500
    private static let searchFetchLimit = 1000

    init(
        modelContainer: ModelContainer,
        profileID: UUID?,
        isGuestSession: Bool = false,
        userDefaults: UserDefaults = .standard
    ) {
        self.profileID = profileID
        self.isGuestSession = isGuestSession
        self.userDefaults = userDefaults
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = true
        self.isSavingEnabled    = isGuestSession ? false : userDefaults.bool(forKey: Self.scopedKey("historySavingEnabled",  profileID: profileID), default: true)
        self.showTopSites       = userDefaults.bool(forKey: Self.scopedKey("historyShowTopSites",     profileID: profileID), default: true)
        self.showHistorySuggestions = userDefaults.bool(forKey: Self.scopedKey("historyShowSuggestions", profileID: profileID), default: true)

        if !isGuestSession {
            refreshRecentEntries()
            refreshTopSites()
        }
    }

    func prepareForRemoval() {
        pendingRefreshTask?.cancel()
        lastRecordedURL.removeAll()
    }

    func record(url: URL, title: String, faviconURL: URL? = nil, tabID: UUID? = nil) {
        guard !isGuestSession, isSavingEnabled else { return }
        guard shouldRecord(url: url) else { return }

        let urlString = url.absoluteString
        if let tid = tabID, lastRecordedURL[tid] == urlString { return }
        if let tid = tabID { lastRecordedURL[tid] = urlString }

        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? url.host ?? urlString
        let faviconString = faviconURL?.absoluteString
        let fetchDescriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.urlString == urlString }
        )

        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            if let entry = existing.first {
                entry.title = finalTitle
                entry.lastVisited = Date()
                entry.visitCount += 1
                if let fs = faviconString { entry.faviconURLString = fs }
            } else {
                let entry = HistoryEntry(
                    urlString: urlString,
                    title: finalTitle,
                    faviconURLString: faviconString
                )
                modelContext.insert(entry)
            }
            try modelContext.save()
        } catch {
            AppLog.error("HistoryManager record failed", error: error)
        }

        scheduleDebouncedRefresh()
    }

    func updateMetadata(for url: URL, title: String, faviconURL: URL? = nil) {
        guard !isGuestSession, isSavingEnabled else { return }
        let urlString = url.absoluteString
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? url.host ?? urlString

        let fetch = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        
        do {
            guard let entry = try modelContext.fetch(fetch).first else { return }
            entry.title = finalTitle
            if let fs = faviconURL?.absoluteString { entry.faviconURLString = fs }
            try modelContext.save()
            scheduleDebouncedRefresh()
        } catch {
            AppLog.error("HistoryManager update metadata failed for \(url.host ?? urlString)", error: error)
        }
    }

    func delete(id: UUID) {
        let fetch = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            guard let entry = try modelContext.fetch(fetch).first else { return }
            modelContext.delete(entry)
            try modelContext.save()
            refreshRecentEntries()
            refreshTopSites()
        } catch {
            AppLog.error("HistoryManager delete failed for id=\(id.uuidString)", error: error)
        }
    }

    func deleteAll(forHost host: String) {
        let fetch = FetchDescriptor<HistoryEntry>()
        do {
            let all = try modelContext.fetch(fetch)
            let matching = all.filter { $0.url?.host == host }
            matching.forEach { modelContext.delete($0) }
            try modelContext.save()
            refreshRecentEntries()
            refreshTopSites()
        } catch {
            AppLog.error("HistoryManager delete all failed for host=\(host)", error: error)
        }
    }

    func clearHistory(since date: Date) {
        let fetch = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.lastVisited >= date }
        )
        do {
            let entries = try modelContext.fetch(fetch)
            entries.forEach { modelContext.delete($0) }
            try modelContext.save()
            refreshRecentEntries()
            refreshTopSites()
            AppLog.info("HistoryManager cleared \(entries.count) entries since \(date)")
        } catch {
            AppLog.error("HistoryManager clear history failed since \(date)", error: error)
        }
    }

    func clearToday() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        clearHistory(since: startOfDay)
    }

    func clearAll() {
        let fetch = FetchDescriptor<HistoryEntry>()
        do {
            let all = try modelContext.fetch(fetch)
            all.forEach { modelContext.delete($0) }
            try modelContext.save()
            recentEntries = []
            topSites = []
            lastRecordedURL.removeAll()
            AppLog.info("HistoryManager cleared all history (\(all.count) entries)")
        } catch {
            AppLog.error("HistoryManager clear all history failed", error: error)
        }
    }

    func allEntries() -> [HistoryEntry] {
        var fetch = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.lastVisited, order: .reverse)]
        )
        fetch.fetchLimit = 2000
        return (try? modelContext.fetch(fetch)) ?? []
    }

    func search(query: String, limit: Int = 100) -> [HistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allEntries() }

        var fetch = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.lastVisited, order: .reverse)]
        )
        fetch.fetchLimit = Self.searchFetchLimit
        let candidates = (try? modelContext.fetch(fetch)) ?? []
        return candidates
            .filter { $0.title.lowercased().contains(q) || $0.urlString.lowercased().contains(q) }
            .prefix(limit)
            .map { $0 }
    }

    func suggestions(for query: String, limit: Int = 6) -> [HistorySuggestion] {
        guard !isGuestSession, showHistorySuggestions else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var fetch = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.lastVisited, order: .reverse)]
        )
        fetch.fetchLimit = Self.suggestionsFetchLimit
        let candidates = (try? modelContext.fetch(fetch)) ?? []

        let now = Date()
        let daySeconds: Double = 86_400

        return candidates
            .filter { $0.title.lowercased().contains(q) || $0.urlString.lowercased().contains(q) }
            .map { entry -> (HistoryEntry, Double) in
                let ageDays = now.timeIntervalSince(entry.lastVisited) / daySeconds
                let recencyBoost = max(0, 1.0 - ageDays / 30.0)
                let titleMatch = entry.title.lowercased().hasPrefix(q) ? 2.0 : 1.0
                let score = Double(entry.visitCount) * (1.0 + recencyBoost) * titleMatch
                return (entry, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { entry, _ in
                HistorySuggestion(
                    id: entry.id,
                    title: entry.displayTitle,
                    urlString: entry.urlString,
                    visitCount: entry.visitCount,
                    lastVisited: entry.lastVisited,
                    faviconURL: entry.faviconURL
                )
            }
    }

    func invalidateTabCache(tabID: UUID) {
        lastRecordedURL.removeValue(forKey: tabID)
    }

    private func scheduleDebouncedRefresh() {
        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.refreshDebounceNs)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            await MainActor.run {
                self.refreshRecentEntries()
                self.refreshTopSites()
            }
        }
    }

    private func refreshRecentEntries() {
        var fetch = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.lastVisited, order: .reverse)]
        )
        fetch.fetchLimit = 500
        recentEntries = (try? modelContext.fetch(fetch)) ?? []
    }

    private func refreshTopSites() {
        guard showTopSites else { topSites = []; return }

        var fetch = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.visitCount, order: .reverse)]
        )
        fetch.fetchLimit = 200
        let candidates = (try? modelContext.fetch(fetch)) ?? []
        let now = Date()
        let daySeconds: Double = 86_400

        var seen = Set<String>()
        topSites = candidates
            .compactMap { entry -> (HistoryEntry, Double)? in
                guard let host = entry.url?.host else { return nil }
                let key = entry.url?.eTLDPlusOne ?? host
                guard !seen.contains(key) else { return nil }
                seen.insert(key)
                let ageDays = now.timeIntervalSince(entry.lastVisited) / daySeconds
                let recency = max(0, 1.0 - ageDays / 30.0)
                let score = Double(entry.visitCount) * (1.0 + recency)
                return (entry, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(8)
            .map { $0.0 }
    }

    private func shouldRecord(url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else { return false }
        let absolute = url.absoluteString
        if absolute == "about:blank" || absolute == "about:newtab" { return false }
        if scheme == "illuminate" { return false }
        return true
    }

    private func settingsKey(_ key: String) -> String {
        Self.scopedKey(key, profileID: profileID)
    }

    private static func scopedKey(_ key: String, profileID: UUID?) -> String {
        if let id = profileID { return "profile.\(id.uuidString).\(key)" }
        return key
    }

    private func persist(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
}

private extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard object(forKey: key) != nil else { return defaultValue }
        return bool(forKey: key)
    }
}
