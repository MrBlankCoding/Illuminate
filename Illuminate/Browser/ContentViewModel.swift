//
//  ContentViewModel.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import Observation

struct IlluminatePageSuggestion: Identifiable, Equatable {
    var id: String { urlString }
    let page: IlluminatePage
    let title: String
    let subtitle: String
    let icon: String
    let urlString: String
    let isCurrentlyOpenTab: Bool
    let openTabID: UUID?
}

@MainActor
@Observable
final class ContentViewModel {
    @ObservationIgnored @AppStorage("defaultSearchEngine") private var defaultSearchEngine: SearchEngine = .google

    var illuminatePageSuggestions: [IlluminatePageSuggestion] = []
    var historySuggestions: [HistorySuggestion] = []
    var webSuggestions: [String] = []

    @ObservationIgnored private let tabManager: TabManager
    @ObservationIgnored private let urlSynchronizer: URLSynchronizer
    @ObservationIgnored private let historyManager: HistoryManager?
    @ObservationIgnored private var webSuggestionTask: Task<Void, Never>?
    @ObservationIgnored private var webSuggestionCache: [String: [String]] = [:]
    @ObservationIgnored private var webSuggestionCacheOrder: [String] = []
    @ObservationIgnored private let webSuggestionCacheLimit = 50
    @ObservationIgnored private var lastSuggestionQuery: String?
    private(set) var isEditingAddressBar = false

    init(
        tabManager: TabManager,
        urlSynchronizer: URLSynchronizer,
        historyManager: HistoryManager? = nil
    ) {
        self.tabManager = tabManager
        self.urlSynchronizer = urlSynchronizer
        self.historyManager = historyManager
    }

    func setAddressBarEditing(_ isEditing: Bool) {
        isEditingAddressBar = isEditing
    }

    func navigateToAddressBarURL(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed == Self.addressBarDisplayText(for: tabManager.activeTab?.url) {
            isEditingAddressBar = false
            cancelSuggestions()
            return
        }

        let destination: URL?
        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            destination = absolute
        } else if trimmed.contains(" ") || !trimmed.contains(".") {
            destination = defaultSearchEngine.searchURL(for: trimmed)
        } else {
            destination = URL(string: "https://\(trimmed)")
        }

        guard let url = destination else { return }

        isEditingAddressBar = false
        cancelSuggestions()

        guard let tab = tabManager.activeTab else { return }
        tab.load(url: url)
        urlSynchronizer.updateCurrentURL(url)
    }

    func createNewTab(url: URL? = nil) {
        tabManager.createTab(url: url)
    }

    func updateSuggestions(for query: String) {
        webSuggestionTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard q.count >= 2 || q.starts(with: "illuminate:") else {
            clearLocalSuggestionsIfNeeded()
            lastSuggestionQuery = nil
            return
        }

        // The illuminate/history scans are pure in-memory work; memoize them
        // per query so repeated keystrokes that normalize to the same query
        // don't rescan.
        if q != lastSuggestionQuery {
            lastSuggestionQuery = q

            let newIlluminateSuggestions = fetchIlluminateSuggestions(for: q)
            if illuminatePageSuggestions != newIlluminateSuggestions {
                illuminatePageSuggestions = newIlluminateSuggestions
            }
            let historyResults = historyManager?.suggestions(for: q, limit: 3) ?? []
            if historySuggestions != historyResults {
                historySuggestions = historyResults
            }
        }

        guard !isLikelyURL(q), !q.starts(with: "illuminate:") else {
            if !webSuggestions.isEmpty { webSuggestions = [] }
            return
        }

        if let cachedResults = webSuggestionCache[q] {
            if webSuggestions != cachedResults {
                webSuggestions = cachedResults
            }
            return
        }

        webSuggestionTask = Task(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            guard !Task.isCancelled, let self else { return }

            let engine = self.defaultSearchEngine
            let results = await Self.fetchWebSuggestions(for: q, engine: engine)
            guard !Task.isCancelled else { return }

            self.storeWebSuggestions(results, for: q)
            if self.webSuggestions != results {
                self.webSuggestions = results
            }
        }
    }

    private func storeWebSuggestions(_ results: [String], for query: String) {
        if let existingIndex = webSuggestionCacheOrder.firstIndex(of: query) {
            webSuggestionCacheOrder.remove(at: existingIndex)
        }
        webSuggestionCacheOrder.append(query)
        webSuggestionCache[query] = results
        while webSuggestionCacheOrder.count > webSuggestionCacheLimit {
            let evicted = webSuggestionCacheOrder.removeFirst()
            webSuggestionCache.removeValue(forKey: evicted)
        }
    }

    private func fetchIlluminateSuggestions(for q: String) -> [IlluminatePageSuggestion] {
        var matchingPages: [IlluminatePage] = []
        if q.starts(with: "illuminate://") {
            let filter = q.replacingOccurrences(of: "illuminate://", with: "")
            matchingPages = filter.isEmpty ? IlluminatePage.suggestiblePages : IlluminatePage.suggestiblePages.filter { page in
                page.rawValue.contains(filter) || page.tabTitle.lowercased().contains(filter)
            }
        } else if q.starts(with: "illuminate:") {
            let filter = q.replacingOccurrences(of: "illuminate:", with: "")
            matchingPages = filter.isEmpty ? IlluminatePage.suggestiblePages : IlluminatePage.suggestiblePages.filter { page in
                page.rawValue.contains(filter) || page.tabTitle.lowercased().contains(filter)
            }
        } else {
            matchingPages = IlluminatePage.suggestiblePages.filter { page in
                page.rawValue.contains(q) || page.tabTitle.lowercased().contains(q)
            }
        }

        let openTabs = tabManager.tabs
        return matchingPages.map { page -> IlluminatePageSuggestion in
            let openTab = openTabs.first { $0.url == page.url }
            return IlluminatePageSuggestion(
                page: page,
                title: page.title,
                subtitle: page.url.absoluteString,
                icon: page.icon,
                urlString: page.url.absoluteString,
                isCurrentlyOpenTab: openTab != nil,
                openTabID: openTab?.id
            )
        }
    }

    func cancelSuggestions() {
        webSuggestionTask?.cancel()
        lastSuggestionQuery = nil
        clearLocalSuggestionsIfNeeded()
    }

    private func clearLocalSuggestionsIfNeeded() {
        if !illuminatePageSuggestions.isEmpty { illuminatePageSuggestions = [] }
        if !historySuggestions.isEmpty { historySuggestions = [] }
        if !webSuggestions.isEmpty { webSuggestions = [] }
    }

    private nonisolated static func fetchWebSuggestions(for query: String, engine: SearchEngine) async -> [String] {
        let url = await MainActor.run { engine.suggestionURL(for: query) }
        guard let url else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            switch engine {
            case .google, .bing:
                guard
                    let payload = try JSONSerialization.jsonObject(with: data) as? [Any],
                    payload.count > 1,
                    let suggestions = payload[1] as? [String]
                else {
                    return []
                }
                return Array(suggestions.prefix(3))
                
            case .duckDuckGo:
                // DuckDuckGo returns an array of objects: [{"phrase":"..."}, ...]
                guard
                    let payload = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                else {
                    return []
                }
                let suggestions = payload.compactMap { $0["phrase"] as? String }
                return Array(suggestions.prefix(3))
            }
        } catch {
            return []
        }
    }

    private func isLikelyURL(_ input: String) -> Bool {
        if let url = URL(string: input), url.scheme != nil {
            return true
        }
        return input.contains(".") && !input.contains(" ")
    }

    static func addressBarDisplayText(for url: URL?) -> String {
        guard let url else { return "" }
        if let page = IlluminatePage(url: url), let source = page.pdfSourceFileURL(from: url) {
            return source.path
        }
        return url.absoluteString
    }
}
