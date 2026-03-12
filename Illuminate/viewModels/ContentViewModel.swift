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
    private var cancellables = Set<AnyCancellable>()
    
    init(tabManager: TabManager) {
        self.tabManager = tabManager
        setupBindings()
    }
    
    func setTabManager(_ manager: TabManager) {
        self.tabManager = manager
        setupBindings()
    }
    
    private func setupBindings() {
        cancellables.removeAll()
        
        tabManager.$activeTabID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateAddressBarFromActiveTab()
            }
            .store(in: &cancellables)
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
            let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            destination = URL(string: "https://www.google.com/search?q=\(query)&sourceid=chrome")
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
        URLSynchronizer.shared.updateCurrentURL(url)
    }
    
    func createNewTab(url: URL? = nil) {
        tabManager.createTab(url: url)
        updateAddressBarFromActiveTab()
    }
}
