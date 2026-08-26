//
//  ViewModelBehaviorTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct ViewModelBehaviorTests {
    @Test func searchQueriesRouteToGoogleWithoutChromeSourceMarker() {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
        let viewModel = ContentViewModel(tabManager: tabManager, urlSynchronizer: synchronizer)
        let tab = try! #require(tabManager.activeTab)

        viewModel.navigateToAddressBarURL("swift ui testing")

        #expect(tab.url?.host == "www.google.com")
        #expect(tab.url?.path == "/search")
        #expect(tab.url?.absoluteString.contains("sourceid=chrome") == false)
        #expect(URLComponents(url: try! #require(tab.url), resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "q" && $0.value == "swift ui testing" }) == true)
        #expect(synchronizer.currentURL == tab.url)
    }

    @Test func switchingTabsUpdatesSynchronizerURL() async {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
        let viewModel = ContentViewModel(tabManager: tabManager, urlSynchronizer: synchronizer)

        let first = try! #require(tabManager.activeTab)
        await MainActor.run { first.load(url: URL(string: "https://first.example.com")!) }

        let second = await MainActor.run { tabManager.createTab(url: URL(string: "https://second.example.com")!) }

        #expect(tabManager.activeTab?.id == second.id)
        // The URLSynchronizer is what the URL bar observes for display text
        // when it isn't focused.
        #expect(synchronizer.currentURL == second.url)

        await MainActor.run { viewModel.setAddressBarEditing(true) }
        await MainActor.run { tabManager.switchTo(first.id) }

        #expect(tabManager.activeTab?.id == first.id)
        #expect(synchronizer.currentURL == first.url)
    }

    @Test func createNewTabWithURLMakesItActive() {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
        let viewModel = ContentViewModel(tabManager: tabManager, urlSynchronizer: synchronizer)
        let url = URL(string: "https://example.com/path")!

        viewModel.createNewTab(url: url)

        #expect(tabManager.activeTab?.url == url)
        #expect(synchronizer.currentURL == url)
        #expect(tabManager.tabs.count == 2)
    }

    @Test func dismissingFindClearsSearchAndMatchState() {
        let viewModel = FindViewModel()
        viewModel.isPresented = true
        viewModel.searchText = "term"
        viewModel.matchFound = true

        viewModel.dismiss()

        #expect(viewModel.isPresented == false)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.matchFound == false)
    }

    @Test func hidingFindViewClearsExistingMatchState() {
        let viewModel = FindViewModel()
        viewModel.matchFound = true
        viewModel.isPresented = true

        viewModel.isPresented = false

        #expect(viewModel.matchFound == false)
    }

    @Test func updateZoomShowsIndicatorAndStoresLevel() {
        let viewModel = ZoomViewModel()

        viewModel.updateZoom(1.5)

        #expect(viewModel.zoomLevel == 1.5)
        #expect(viewModel.isPresented == true)
    }

    @Test func hidingZoomIndicatorCancelsPresentationImmediately() {
        let viewModel = ZoomViewModel()
        viewModel.show()

        viewModel.hide()

        #expect(viewModel.isPresented == false)
    }

    @Test func loadingIlluminateURLUpdatesTabTitle() {
        let tab = Tab(url: URL(string: "illuminate://info")!)
        #expect(tab.title == "Browser Info")

        tab.load(url: URL(string: "illuminate://passwords")!)
        #expect(tab.title == "Passwords")

        tab.load(url: URL(string: "illuminate://protection")!)
        #expect(tab.title == "Protection")
    }

    @Test
    func updateSuggestionsIncludesIlluminatePageSuggestions() async throws {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(
            urlSynchronizer: synchronizer,
            isPersistenceEnabled: false
        )
        let viewModel = ContentViewModel(
            tabManager: tabManager,
            urlSynchronizer: synchronizer
        )

        viewModel.updateSuggestions(for: "info")
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.illuminatePageSuggestions.contains { $0.page == .info })

        viewModel.updateSuggestions(for: "illuminate://")
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(
            viewModel.illuminatePageSuggestions.count == IlluminatePage.suggestiblePages.count
        )

        let infoURL = URL(string: "illuminate://info")!
        let openTab = tabManager.createTab(url: infoURL)

        viewModel.updateSuggestions(for: "info")
        try await Task.sleep(nanoseconds: 100_000_000)

        let infoSuggestion = viewModel.illuminatePageSuggestions
            .first { $0.page == .info }

        #expect(infoSuggestion?.isCurrentlyOpenTab == true)
        #expect(infoSuggestion?.openTabID == openTab.id)
    }
}
