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

        viewModel.addressBarText = "swift ui testing"
        viewModel.navigateToAddressBarURL()

        #expect(tab.url?.host == "www.google.com")
        #expect(tab.url?.path == "/search")
        #expect(tab.url?.absoluteString.contains("sourceid=chrome") == false)
        #expect(URLComponents(url: try! #require(tab.url), resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "q" && $0.value == "swift ui testing" }) == true)
        #expect(synchronizer.currentURL == tab.url)
    }

    @Test func createNewTabWithURLMakesItActiveAndUpdatesAddressBar() {
        let synchronizer = URLSynchronizer()
        let tabManager = TabManager(urlSynchronizer: synchronizer, isPersistenceEnabled: false)
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
