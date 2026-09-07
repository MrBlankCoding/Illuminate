//
//  ContentViewModelStateTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct ContentViewModelStateTests {
    private func makeViewModelAndTab() -> (ContentViewModel, Tab) {
        let tabManager = TabManager(isPersistenceEnabled: false)
        let viewModel = ContentViewModel(
            tabManager: tabManager,
            urlSynchronizer: URLSynchronizer()
        )
        let tab = tabManager.createTab()
        tabManager.switchTo(tab.id)
        return (viewModel, tab)
    }

    @Test func blankAddressBarDoesNothingAndKeepsExistingTabURL() {
        let (viewModel, tab) = makeViewModelAndTab()
        let original = tab.url

        viewModel.navigateToAddressBarURL("   ")

        #expect(tab.url == original)
        #expect(viewModel.isEditingAddressBar == false)
    }

    @Test func cancelSuggestionsClearsAllSuggestionCollections() {
        let (viewModel, _) = makeViewModelAndTab()

        viewModel.updateSuggestions(for: "illuminate:")
        #expect(viewModel.illuminatePageSuggestions.isEmpty == false)

        viewModel.cancelSuggestions()

        #expect(viewModel.illuminatePageSuggestions.isEmpty)
        #expect(viewModel.historySuggestions.isEmpty)
        #expect(viewModel.webSuggestions.isEmpty)
    }

    @Test func directURLWithSchemeIsPreservedWithoutAutoPrefixing() {
        let (viewModel, tab) = makeViewModelAndTab()

        viewModel.navigateToAddressBarURL("mailto:test@example.com")

        #expect(tab.url?.absoluteString == "mailto:test@example.com")
    }

    @Test func illuminatePageURLIsLoadedAsInternal() {
        let (viewModel, tab) = makeViewModelAndTab()

        viewModel.navigateToAddressBarURL("illuminate://history")

        #expect(tab.url?.absoluteString == "illuminate://history")
    }

    @Test func nonUrlQueryIsLoadedAsSearch() {
        let (viewModel, tab) = makeViewModelAndTab()

        // A query with no recognized scheme and no dot is treated as a search.
        viewModel.navigateToAddressBarURL("hello world")

        #expect(tab.url?.host == "www.google.com")
        #expect(tab.url?.path == "/search")
    }

    @Test func addressBarWithSchemeAndSpaceIsTreatedAsSearch() {
        let (viewModel, tab) = makeViewModelAndTab()

        viewModel.navigateToAddressBarURL("https://example.com path")
        #expect(tab.url?.scheme == "https")
    }

    @Test func addressBarHTTPSWithNoPathLoadsRoot() {
        let (viewModel, tab) = makeViewModelAndTab()

        viewModel.navigateToAddressBarURL("https://example.com")

        #expect(tab.url?.absoluteString == "https://example.com")
    }

    @Test func addressBarHTTPSWithPortIsPreserved() {
        let (viewModel, tab) = makeViewModelAndTab()

        viewModel.navigateToAddressBarURL("https://example.com:8443/path")

        #expect(tab.url?.absoluteString == "https://example.com:8443/path")
    }

    @Test func emptyQueryAfterTrimDoesNotNavigate() {
        let (viewModel, tab) = makeViewModelAndTab()
        let original = tab.url

        viewModel.navigateToAddressBarURL("       ")

        #expect(tab.url == original)
    }

    @Test func currentURLUpdateIsObserved() {
        let tabManager = TabManager(isPersistenceEnabled: false)
        let sync = URLSynchronizer()
        let viewModel = ContentViewModel(tabManager: tabManager, urlSynchronizer: sync)
        let tab = tabManager.createTab()
        tabManager.switchTo(tab.id)

        viewModel.navigateToAddressBarURL("https://example.com")

        #expect(sync.currentURL?.absoluteString == "https://example.com")
    }
}
