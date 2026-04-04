//
//  ViewModelBehaviorTests.swift
//  IlluminateTests
//
//  Created by Codex.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct ViewModelBehaviorTests {

    @Test func navigateToSettingsURLUsesInternalSettingsRoute() async throws {
        let tabManager = TabManager(isPersistenceEnabled: false)
        let synchronizer = URLSynchronizer()
        let viewModel = ContentViewModel(tabManager: tabManager, urlSynchronizer: synchronizer)
        let tab = try #require(tabManager.activeTab)

        viewModel.addressBarText = "illuminate://settings"
        viewModel.navigateToAddressBarURL()

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(tab.url?.absoluteString == "illuminate://settings")
        #expect(tab.title == "Settings")
        #expect(synchronizer.currentURL?.absoluteString == "illuminate://settings")
    }

    @Test func createNewTabWithURLMakesItActiveAndUpdatesAddressBar() {
        let tabManager = TabManager(isPersistenceEnabled: false)
        let synchronizer = URLSynchronizer()
        let viewModel = ContentViewModel(tabManager: tabManager, urlSynchronizer: synchronizer)
        let url = URL(string: "https://example.com/path")!

        viewModel.createNewTab(url: url)

        #expect(tabManager.activeTab?.url == url)
        #expect(viewModel.addressBarText == url.absoluteString)
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
}
