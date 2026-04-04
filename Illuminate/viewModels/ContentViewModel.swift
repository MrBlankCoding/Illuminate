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
    
    private var tabManager: TabManager
    private var urlSynchronizer: URLSynchronizer
    private var cancellables = Set<AnyCancellable>()
    private var activeTabURLCancellable: AnyCancellable?
    
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
                self?.updateAddressBarFromActiveTab()
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
                .sink { [weak self] url in
                    self?.addressBarText = url?.absoluteString ?? ""
                }
        }
    }
    
    func updateAddressBarFromActiveTab() {
        if let url = tabManager.activeTab?.url {
            addressBarText = url.absoluteString
        } else {
            addressBarText = ""
        }
    }
    
    func navigateToAddressBarURL() {
        guard let tab = tabManager.activeTab else {
            return
        }

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

        if url.absoluteString == "illuminate://settings" {
            DispatchQueue.main.async {
                tab.url = url
                tab.title = "Settings"
            }
        } else {
            tab.load(url: url)
        }
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
}
