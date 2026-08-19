//
//  ContentViewModel.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import SwiftUI
import Combine

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var addressBarText = ""

    @Published private(set) var historySuggestions: [HistorySuggestion] = []
    @Published private(set) var webSuggestions: [String] = []

    private let tabManager: TabManager
    private let urlSynchronizer: URLSynchronizer
    private let historyManager: HistoryManager?
    private var cancellables = Set<AnyCancellable>()
    private var activeTabURLCancellable: AnyCancellable?
    private var webSuggestionTask: Task<Void, Never>?
    private var webSuggestionCache: [String: [String]] = [:]
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
                self?.syncAddressBarFromActiveTab()
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
            cancelSuggestions()
            DispatchQueue.main.async { [weak self] in
                self?.syncAddressBarFromActiveTab(force: true)
            }
        }
    }

    func navigateToAddressBarURL() {
        let trimmed = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

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
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard q.count >= 2 else {
            historySuggestions = []
            webSuggestions = []
            return
        }

        let historyResults = historyManager?.suggestions(for: q, limit: 3) ?? []
        if historySuggestions != historyResults {
            historySuggestions = historyResults
        }

        guard !isLikelyURL(q) else {
            webSuggestions = []
            return
        }

        if let cachedResults = webSuggestionCache[q] {
            if webSuggestions != cachedResults {
                webSuggestions = cachedResults
            }
            return
        }

        webSuggestionTask = Task { [weak self] in
            let results = await Self.fetchWebSuggestions(for: q)
            guard !Task.isCancelled, let self else { return }
            if self.webSuggestionCache.count >= 50 {
                self.webSuggestionCache.removeAll(keepingCapacity: true)
            }
            self.webSuggestionCache[q] = results
            guard self.webSuggestions != results else { return }
            self.webSuggestions = results
        }
    }

    func cancelSuggestions() {
        webSuggestionTask?.cancel()
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
        addressBarText = tabManager.activeTab?.url?.absoluteString ?? ""
    }
}
