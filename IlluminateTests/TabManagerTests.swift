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

    @Test func reopenClosedTabRestoresLastClosedTab() {
        let tabManager = TabManager(isPersistenceEnabled: false)
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

    @Test func clearAllTabsRemovesEverythingAndDisablesFurtherReopenAfterDrain() {
        let tabManager = TabManager(isPersistenceEnabled: false)
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

    @Test func tabGroupsCanBeAssignedAndRemoved() {
        let tabManager = TabManager(isPersistenceEnabled: false)
        let tab = tabManager.createTab(url: URL(string: "https://grouped.example"))

        tabManager.createTabGroup(name: "Work", color: "FF0000")
        let group = try! #require(tabManager.tabGroups.first)

        tabManager.setTabGroup(tabID: tab.id, groupID: group.id)
        #expect(tab.groupID == group.id)

        tabManager.removeTabGroup(id: group.id)
        #expect(tabManager.tabGroups.isEmpty)
        #expect(tab.groupID == nil)
    }

    @Test func updateTabURLSynchronizesActiveTabURL() async throws {
        let tabManager = TabManager(isPersistenceEnabled: false)
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
        let tabManager = TabManager(isPersistenceEnabled: false)
        let firstTab = tabManager.createTab(url: URL(string: "https://one.example"))
        let secondTab = tabManager.createTab(url: URL(string: "https://two.example"))

        firstTab.createWebViewIfNeeded(configuration: WebKitManager.shared.makeConfiguration())
        secondTab.createWebViewIfNeeded(configuration: WebKitManager.shared.makeConfiguration())

        let firstWebView = firstTab.webView
        let secondWebView = secondTab.webView

        tabManager.switchTo(firstTab.id)

        #expect(firstTab.webView === firstWebView)
        #expect(secondTab.webView === secondWebView)
        #expect(secondTab.isHibernated == false)
    }
}
