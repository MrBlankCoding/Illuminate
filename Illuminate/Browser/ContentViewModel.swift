//
//  ContentViewModel.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import Combine

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
final class ContentViewModel: ObservableObject {
    @Published var addressBarText = ""

    @Published private(set) var illuminatePageSuggestions: [IlluminatePageSuggestion] = []
    @Published private(set) var historySuggestions: [HistorySuggestion] = []
    @Published private(set) var webSuggestions: [String] = []

    private let tabManager: TabManager
    private let urlSynchronizer: URLSynchronizer
    private let historyManager: HistoryManager?
    private var cancellables = Set<AnyCancellable>()
    private var activeTabURLCancellable: AnyCancellable?
    private var webSuggestionTask: Task<Void, Never>?
    private var webSuggestionCache: [String: [String]] = [:]
    private var webSuggestionCacheOrder: [String] = []
    private let webSuggestionCacheLimit = 50
    private(set) var isEditingAddressBar = false

    init(
        tabManager: TabManager,
        urlSynchronizer: URLSynchronizer,
        historyManager: HistoryManager? = nil
    ) {
        self.tabManager = tabManager
        self.urlSynchronizer = urlSynchronizer
        self.historyManager = historyManager
        setupBindings()
    }

    private func setupBindings() {
        cancellables.removeAll()

        tabManager.$activeTabID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncAddressBarFromActiveTab(force: true)
                self?.subscribeToActiveTabURL()
            }
            .store(in: &cancellables)

        subscribeToActiveTabURL()
    }

    private func subscribeToActiveTabURL() {
        activeTabURLCancellable?.cancel()
        activeTabURLCancellable = nil

        if let activeTab = tabManager.activeTab {
            activeTabURLCancellable = activeTab.$url
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.syncAddressBarFromActiveTab()
                }
        }
    }

    func updateAddressBarFromActiveTab() {
        syncAddressBarFromActiveTab(force: true)
    }

    func setAddressBarEditing(_ isEditing: Bool) {
        isEditingAddressBar = isEditing
        if !isEditing {
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isEditingAddressBar else { return }
                self.syncAddressBarFromActiveTab()
            }
        }
    }

    func navigateToAddressBarURL() {
        let trimmed = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
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
            destination = googleSearchURL(for: trimmed)
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
        updateAddressBarFromActiveTab()
    }

    func updateSuggestions(for query: String) {
        webSuggestionTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard q.count >= 2 || q.starts(with: "illuminate:") else {
            illuminatePageSuggestions = []
            historySuggestions = []
            webSuggestions = []
            return
        }

        let newIlluminateSuggestions = fetchIlluminateSuggestions(for: q)
        if illuminatePageSuggestions != newIlluminateSuggestions {
            illuminatePageSuggestions = newIlluminateSuggestions
        }
        let historyResults = historyManager?.suggestions(for: q, limit: 3) ?? []
        if historySuggestions != historyResults {
            historySuggestions = historyResults
        }

        guard !isLikelyURL(q), !q.starts(with: "illuminate:") else {
            webSuggestions = []
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

            let results = await Self.fetchWebSuggestions(for: q)
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
        illuminatePageSuggestions = []
        historySuggestions = []
        webSuggestions = []
    }

    private nonisolated static func fetchWebSuggestions(for query: String) async -> [String] {
        guard
            let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://suggestqueries.google.com/complete/search?client=chrome&q=\(escaped)")
        else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard
                let payload = try JSONSerialization.jsonObject(with: data) as? [Any],
                payload.count > 1,
                let suggestions = payload[1] as? [String]
            else {
                return []
            }
            return Array(suggestions.prefix(3))
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

    private func googleSearchURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url
    }

    private func syncAddressBarFromActiveTab(force: Bool = false) {
        guard force || !isEditingAddressBar else { return }
        addressBarText = Self.addressBarDisplayText(for: tabManager.activeTab?.url)
    }

    static func addressBarDisplayText(for url: URL?) -> String {
        guard let url else { return "" }
        if let page = IlluminatePage(url: url), let source = page.pdfSourceFileURL(from: url) {
            return source.path
        }
        return url.absoluteString
    }
}
