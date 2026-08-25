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

    private struct SuggestionCandidate {
        let id: UUID
        let displayTitle: String
        let urlString: String
        let visitCount: Int
        let lastVisited: Date
        let faviconURL: URL?
        let lowercaseTitle: String
        let lowercaseURL: String

        init(entry: HistoryEntry) {
            id = entry.id
            displayTitle = entry.displayTitle
            urlString = entry.urlString
            visitCount = entry.visitCount
            lastVisited = entry.lastVisited
            faviconURL = entry.faviconURL
            lowercaseTitle = entry.title.lowercased()
            lowercaseURL = entry.urlString.lowercased()
        }
    }

    @Published private(set) var recentEntries: [HistoryEntry] = []
    private var suggestionCandidates: [SuggestionCandidate] = []
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

    private let modelContainer: ModelContainer
    private let profileID: UUID?
    private let isGuestSession: Bool
    private let userDefaults: UserDefaults
    private var lastRecordedURL: [UUID: String] = [:]
    private var pendingRefreshTask: Task<Void, Never>?
    private static let refreshDebounceNs: UInt64 = 300_000_000 // 300 ms

    private static let searchFetchLimit = 1000
    private let actor: HistoryModelActor

    init(
        modelContainer: ModelContainer,
        profileID: UUID?,
        isGuestSession: Bool = false,
        userDefaults: UserDefaults = .standard
    ) {
        self.modelContainer = modelContainer
        self.profileID = profileID
        self.isGuestSession = isGuestSession
        self.userDefaults = userDefaults
        self.actor = HistoryModelActor(modelContainer: modelContainer)
        
        self.isSavingEnabled    = isGuestSession ? false : userDefaults.bool(forKey: Self.scopedKey("historySavingEnabled",  profileID: profileID), default: true)
        self.showTopSites       = userDefaults.bool(forKey: Self.scopedKey("historyShowTopSites",     profileID: profileID), default: true)
        self.showHistorySuggestions = userDefaults.bool(forKey: Self.scopedKey("historyShowSuggestions", profileID: profileID), default: true)
    }

    func loadInitialData() {
        guard !isGuestSession else { return }
        scheduleDebouncedRefresh()
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
        
        Task.detached(priority: .utility) { [actor] in
            await actor.record(urlString: urlString, title: finalTitle, faviconURLString: faviconString)
            await MainActor.run { [weak self] in
                self?.scheduleDebouncedRefresh()
            }
        }
    }

    func updateMetadata(for url: URL, title: String, faviconURL: URL? = nil) {
        guard !isGuestSession, isSavingEnabled else { return }
        let urlString = url.absoluteString
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? url.host ?? urlString
        let faviconString = faviconURL?.absoluteString
        
        Task.detached(priority: .utility) { [actor] in
            await actor.updateMetadata(urlString: urlString, title: finalTitle, faviconURLString: faviconString)
            await MainActor.run { [weak self] in
                self?.scheduleDebouncedRefresh()
            }
        }
    }

    func delete(id: UUID) {
        Task.detached(priority: .userInitiated) { [actor] in
            await actor.delete(id: id)
            await MainActor.run { [weak self] in
                self?.refreshRecentEntries()
                self?.refreshTopSites()
            }
        }
    }

    func deleteAll(forHost host: String) {
        Task.detached(priority: .userInitiated) { [actor] in
            await actor.deleteAll(forHost: host)
            await MainActor.run { [weak self] in
                self?.refreshRecentEntries()
                self?.refreshTopSites()
            }
        }
    }

    func clearHistory(since date: Date) {
        Task.detached(priority: .userInitiated) { [actor] in
            await actor.clearHistory(since: date)
            await MainActor.run { [weak self] in
                self?.refreshRecentEntries()
                self?.refreshTopSites()
            }
        }
    }

    func clearToday() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        clearHistory(since: startOfDay)
    }

    func clearAll() {
        Task.detached(priority: .userInitiated) { [actor] in
            await actor.clearAll()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.recentEntries = []
                self.suggestionCandidates = []
                self.topSites = []
                self.lastRecordedURL.removeAll()
            }
        }
    }

    func allEntries() async -> [HistoryEntry] {
        return await actor.fetchRecentEntries(limit: 2000)
    }

    func search(query: String, limit: Int = 100) async -> [HistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return await allEntries() }
        return await actor.search(query: q, limit: limit)
    }

    func suggestions(for query: String, limit: Int = 6) -> [HistorySuggestion] {
        guard !isGuestSession, showHistorySuggestions else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        // Scoring runs against precomputed lowercase keys (rebuilt only when
        // history refreshes) so per-keystroke work never allocates strings.
        let candidates = suggestionCandidates
        let now = Date()
        let daySeconds: Double = 86_400

        return candidates
            .filter { $0.lowercaseTitle.contains(q) || $0.lowercaseURL.contains(q) }
            .map { entry -> (SuggestionCandidate, Double) in
                let ageDays = now.timeIntervalSince(entry.lastVisited) / daySeconds
                let recencyBoost = max(0, 1.0 - ageDays / 30.0)
                let titleMatch = entry.lowercaseTitle.hasPrefix(q) ? 2.0 : 1.0
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
            guard !Task.isCancelled, let self else { return }
            
            let recent = await self.actor.fetchRecentEntries(limit: 500)
            let top = self.showTopSites ? await self.actor.fetchTopSites(limit: 8) : []
            
            await MainActor.run {
                self.recentEntries = recent
                self.topSites = top
                self.rebuildSuggestionCandidates()
            }
        }
    }

    private func rebuildSuggestionCandidates() {
        suggestionCandidates = recentEntries.map(SuggestionCandidate.init)
    }

    private func refreshRecentEntries() {
        Task { [weak self] in
            guard let self else { return }
            let recent = await self.actor.fetchRecentEntries(limit: 500)
            await MainActor.run { self.recentEntries = recent; self.rebuildSuggestionCandidates() }
        }
    }

    private func refreshTopSites() {
        guard showTopSites else { topSites = []; return }
        Task { [weak self] in
            guard let self else { return }
            let top = await self.actor.fetchTopSites(limit: 8)
            await MainActor.run { self.topSites = top }
        }
    }

    private func shouldRecord(url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else { return false }
        let absolute = url.absoluteString
        if absolute == "about:blank" || absolute == "about:newtab" { return false }
        if scheme == "illuminate" { return false }
        if scheme == "webkit-extension" { return false }
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

@available(macOS 14, iOS 17, *)
actor HistoryModelActor: ModelActor {
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    func record(urlString: String, title: String, faviconURLString: String?) {
        let fetchDescriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        
        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            if let entry = existing.first {
                entry.title = title
                entry.lastVisited = Date()
                entry.visitCount += 1
                if let fs = faviconURLString { entry.faviconURLString = fs }
            } else {
                let entry = HistoryEntry(
                    urlString: urlString,
                    title: title,
                    faviconURLString: faviconURLString
                )
                modelContext.insert(entry)
            }
            try modelContext.save()
        } catch {
            AppLog.error("HistoryModelActor record failed", error: error)
        }
    }

    func updateMetadata(urlString: String, title: String, faviconURLString: String?) {
        let fetch = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        do {
            guard let entry = try modelContext.fetch(fetch).first else { return }
            entry.title = title
            if let fs = faviconURLString { entry.faviconURLString = fs }
            try modelContext.save()
        } catch {
            AppLog.error("HistoryModelActor update metadata failed", error: error)
        }
    }

    func delete(id: UUID) {
        let fetch = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            let entries = try modelContext.fetch(fetch)
            for entry in entries { modelContext.delete(entry) }
            try modelContext.save()
        } catch {
            AppLog.error("HistoryModelActor delete failed", error: error)
        }
    }

    func deleteAll(forHost host: String) {
        let fetch = FetchDescriptor<HistoryEntry>()
        do {
            let all = try modelContext.fetch(fetch)
            let matching = all.filter { $0.url?.host == host }
            for entry in matching { modelContext.delete(entry) }
            try modelContext.save()
        } catch {
            AppLog.error("HistoryModelActor delete all for host failed", error: error)
        }
    }

    func clearHistory(since date: Date) {
        let fetch = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.lastVisited >= date }
        )
        do {
            let entries = try modelContext.fetch(fetch)
            for entry in entries { modelContext.delete(entry) }
            try modelContext.save()
        } catch {
            AppLog.error("HistoryModelActor clear history failed", error: error)
        }
    }

    func clearAll() {
        let fetch = FetchDescriptor<HistoryEntry>()
        do {
            let entries = try modelContext.fetch(fetch)
            for entry in entries { modelContext.delete(entry) }
            try modelContext.save()
        } catch {
            AppLog.error("HistoryModelActor clear all failed", error: error)
        }
    }

    func fetchRecentEntries(limit: Int) -> [HistoryEntry] {
        var fetch = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.lastVisited, order: .reverse)]
        )
        fetch.fetchLimit = limit
        return (try? modelContext.fetch(fetch)) ?? []
    }

    func fetchTopSites(limit: Int) -> [HistoryEntry] {
        var fetch = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.visitCount, order: .reverse)]
        )
        fetch.fetchLimit = 200 // Fetch a larger candidate set to filter unique hosts
        let candidates = (try? modelContext.fetch(fetch)) ?? []
        
        var seen = Set<String>()
        return candidates.compactMap { entry -> HistoryEntry? in
            guard let host = entry.url?.host else { return nil }
            let key = entry.url?.eTLDPlusOne ?? host
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return entry
        }.prefix(limit).map { $0 }
    }

    func search(query: String, limit: Int) -> [HistoryEntry] {
        var fetch = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.lastVisited, order: .reverse)]
        )
        fetch.fetchLimit = 1000
        let candidates = (try? modelContext.fetch(fetch)) ?? []
        return candidates
            .filter { $0.title.lowercased().contains(query) || $0.urlString.lowercased().contains(query) }
            .prefix(limit)
            .map { $0 }
    }
}

private extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard object(forKey: key) != nil else { return defaultValue }
        return bool(forKey: key)
    }
}
