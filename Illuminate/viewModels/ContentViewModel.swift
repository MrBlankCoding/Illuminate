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
    
    private let tabManager: TabManager
    private let urlSynchronizer: URLSynchronizer
    private var cancellables = Set<AnyCancellable>()
    private var activeTabURLCancellable: AnyCancellable?
    private var isEditingAddressBar = false
    
    init(tabManager: TabManager, urlSynchronizer: URLSynchronizer) {
        self.tabManager = tabManager
        self.urlSynchronizer = urlSynchronizer
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
        // Cancel the previous URL subscription
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
            // Defer the sync so any in-flight navigateToAddressBarURL call can
            // read the current text before we reset it.
            DispatchQueue.main.async { [weak self] in
                self?.syncAddressBarFromActiveTab(force: true)
            }
        }
    }
    
    func navigateToAddressBarURL() {
        let trimmed = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
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

        guard let url = destination else {
            return
        }

        isEditingAddressBar = false

        guard let tab = tabManager.activeTab else {
            return
        }
        tab.load(url: url)
        urlSynchronizer.updateCurrentURL(url)
    }
    
    func createNewTab(url: URL? = nil) {
        tabManager.createTab(url: url)
        updateAddressBarFromActiveTab()
    }

    private func googleSearchURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        return components.url
    }

    private func syncAddressBarFromActiveTab(force: Bool = false) {
        guard force || !isEditingAddressBar else { return }
        addressBarText = tabManager.activeTab?.url?.absoluteString ?? ""
    }
}
