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

    private let tabManager: TabManager
    private let urlSynchronizer: URLSynchronizer
    private let historyManager: HistoryManager?
    private var cancellables = Set<AnyCancellable>()
    private var activeTabURLCancellable: AnyCancellable?
    private var suggestionTask: Task<Void, Never>?
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
        suggestionTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !q.isEmpty, let historyManager else {
            historySuggestions = []
            return
        }

        suggestionTask = Task { [weak self, weak historyManager] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled, let self, let historyManager else { return }
            let results = historyManager.suggestions(for: q, limit: 6)
            guard !Task.isCancelled else { return }
            self.historySuggestions = results
        }
    }

    func cancelSuggestions() {
        suggestionTask?.cancel()
        historySuggestions = []
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
