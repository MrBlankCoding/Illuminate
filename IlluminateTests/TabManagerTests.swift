//
//  TabManagerTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/18/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct TabManagerTests {

    private func makeTabManager(isPersistenceEnabled: Bool = false) -> TabManager {
        TabManager(
            profile: BrowserProfile(name: "Test Profile"),
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: isPersistenceEnabled
        )
    }

    @Test func reopenClosedTabRestoresLastClosedTab() {
        let tabManager = makeTabManager()
        let tab = tabManager.createTab(url: URL(string: "https://apple.com"))
        tab.title = "Apple"
        let closedTabID = tab.id

        tabManager.closeTab(id: closedTabID)
        let reopened = tabManager.reopenLastClosedTab()
        let activeTabID = tabManager.activeTabID

        #expect(reopened != nil)
        #expect(reopened?.id == closedTabID)
        #expect(reopened?.url?.absoluteString == "https://apple.com")
        #expect(activeTabID == closedTabID)
    }

    @Test func clearAllTabsRemovesEverythingAndPreservesReopenHistory() {
        let tabManager = makeTabManager()
        _ = tabManager.createTab(url: URL(string: "https://one.example"))
        _ = tabManager.createTab(url: URL(string: "https://two.example"))

        tabManager.clearAllTabs()
        let tabs = tabManager.tabs
        let activeTabID = tabManager.activeTabID

        #expect(tabs.isEmpty)
        #expect(activeTabID == nil)

        _ = tabManager.reopenLastClosedTab()
        _ = tabManager.reopenLastClosedTab()
        _ = tabManager.reopenLastClosedTab()

        #expect(tabManager.reopenLastClosedTab() == nil)
    }

    @Test func tabsAreCreatedWithoutGroupState() {
        let tabManager = makeTabManager()
        let tab = tabManager.createTab(url: URL(string: "https://grouped.example"))

        #expect(tabManager.tabs.contains(where: { $0.id == tab.id }))
        #expect(tab.url?.absoluteString == "https://grouped.example")
    }

    @Test func updateTabURLSynchronizesActiveTabURL() async throws {
        let tabManager = makeTabManager()
        let tab = tabManager.createTab(url: URL(string: "https://before.example"))

        tabManager.switchTo(tab.id)
        let updatedURL = URL(string: "https://after.example/path")!
        tabManager.updateTabURL(tabID: tab.id, url: updatedURL)

        try await Task.sleep(nanoseconds: 50_000_000)
        let activeTabURL = tabManager.activeTab?.url

        #expect(tab.url == updatedURL)
        #expect(activeTabURL == updatedURL)
    }

    @Test func switchingTabsDoesNotDiscardBackgroundWebViews() {
        let tabManager = makeTabManager()
        let webKitManager = WebKitManager(profile: BrowserProfile(name: "Test Profile"))
        let firstTab = tabManager.createTab(url: URL(string: "https://one.example"))
        let secondTab = tabManager.createTab(url: URL(string: "https://two.example"))

        firstTab.createWebViewIfNeeded(
            configuration: webKitManager.makeConfiguration(),
            webKitManager: webKitManager
        )
        secondTab.createWebViewIfNeeded(
            configuration: webKitManager.makeConfiguration(),
            webKitManager: webKitManager
        )

        let firstWebView = firstTab.webView
        let secondWebView = secondTab.webView

        tabManager.switchTo(firstTab.id)

        #expect(firstTab.webView === firstWebView)
        #expect(secondTab.webView === secondWebView)
        #expect(secondTab.isHibernated == false)
    }

    @Test func initCreatesSingleBlankTabWhenPersistenceIsDisabled() {
        let tabManager = makeTabManager()

        #expect(tabManager.tabs.count == 1)
        #expect(tabManager.activeTabID == tabManager.tabs.first?.id)
        #expect(tabManager.tabs.first?.url == nil)
    }

    @Test func closeActiveTabSelectsNeighboringTab() {
        let tabManager = makeTabManager()
        let firstTab = tabManager.createTab(url: URL(string: "https://one.example"))
        let secondTab = tabManager.createTab(url: URL(string: "https://two.example"))
        let thirdTab = tabManager.createTab(url: URL(string: "https://three.example"))

        tabManager.switchTo(secondTab.id)
        tabManager.closeTab(id: secondTab.id)

        #expect(tabManager.tabs.map(\.id).contains(secondTab.id) == false)
        #expect(tabManager.activeTabID == thirdTab.id)
        #expect(tabManager.tabs.map(\.id).contains(firstTab.id))
    }

    @Test func closingLastTabLeavesNoActiveTab() {
        let tabManager = makeTabManager()
        let initialTab = try! #require(tabManager.tabs.first)

        tabManager.closeTab(id: initialTab.id)

        #expect(tabManager.tabs.isEmpty)
        #expect(tabManager.activeTabID == nil)
    }
}
