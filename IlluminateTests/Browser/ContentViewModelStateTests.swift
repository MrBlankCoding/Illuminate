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
}
