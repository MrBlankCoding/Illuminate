//
//  TabManagerCoverageTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct TabManagerCoverageTests {
    private func makeManager() -> TabManager {
        TabManager(
            profile: BrowserProfile(name: "Coverage"),
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: false
        )
    }

    @Test func bookmarkBarCyclesThroughAllStates() {
        let manager = makeManager()
        let first = manager.bookmarkBarVisibility
        manager.cycleBookmarkBarVisibility()
        let second = manager.bookmarkBarVisibility
        manager.cycleBookmarkBarVisibility()
        let third = manager.bookmarkBarVisibility
        manager.cycleBookmarkBarVisibility()
        #expect(first != second)
        #expect(second != third)
        #expect(manager.bookmarkBarVisibility == first)
    }

    @Test func navigationUpdatesActiveTabAndMissingTabIsIgnored() {
        let manager = makeManager()
        let tab = manager.createTab(url: URL(string: "https://before.example"))
        manager.switchTo(tab.id)
        let updated = URL(string: "https://after.example/path")!
        manager.navigateActiveTab(to: updated)
        #expect(tab.url == updated)
        manager.updateTabURL(tabID: UUID(), url: URL(string: "https://ignored.example"))
        #expect(manager.tabs.count == 2)
    }

    @Test func moveAndCycleTabsPreserveSelection() {
        let manager = makeManager()
        let one = manager.createTab(url: URL(string: "https://one.example"))
        let two = manager.createTab(url: URL(string: "https://two.example"))
        let three = manager.createTab(url: URL(string: "https://three.example"))
        manager.switchTo(one.id)
        manager.nextTab()
        #expect(manager.activeTabID == two.id)
        manager.previousTab()
        #expect(manager.activeTabID == one.id)
        manager.moveTab(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(manager.tabs.count == 4)
        #expect(manager.tabs.contains(where: { $0.id == three.id }))
    }

    @Test func clearAndEnsureRestoresRequiredBlankTab() {
        let manager = makeManager()
        manager.clearAllTabs()
        #expect(manager.tabs.isEmpty)
        manager.ensureHasAtLeastOneTab()
        #expect(manager.tabs.count == 1)
        #expect(manager.activeTabID == manager.tabs.first?.id)
        manager.closeTab(id: UUID())
        #expect(manager.tabs.count == 1)
    }
}
