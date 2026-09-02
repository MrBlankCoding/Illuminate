//
//  TabStateTransitionTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct TabStateTransitionTests {
    private func makeManager() -> TabManager {
        TabManager(
            profile: BrowserProfile(name: "State Test"),
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: false
        )
    }

    @Test func setActiveTabIgnoresMissingTabIDs() {
        let manager = makeManager()
        let first = manager.createTab(url: URL(string: "https://first.example"))
        _ = manager.createTab(url: URL(string: "https://second.example"))

        manager.setActiveTab(first.id)
        let selectedBefore = manager.activeTabID

        manager.setActiveTab(UUID())

        #expect(manager.activeTabID == selectedBefore)
        #expect(manager.activeTab?.id == first.id)
    }

    @Test func switchToMostRecentTabPrefersNewestInactiveTab() {
        let manager = makeManager()
        let first = manager.createTab(url: URL(string: "https://first.example"))
        let second = manager.createTab(url: URL(string: "https://second.example"))
        let third = manager.createTab(url: URL(string: "https://third.example"))

        manager.setActiveTab(first.id)
        first.markActivated()
        second.markActivated()
        third.markActivated()

        manager.switchToMostRecentTab()

        #expect(manager.activeTabID == third.id)
    }

    @Test func createdTabsRemainSelectedUntilAnotherTabIsActivated() {
        let manager = makeManager()
        let first = manager.createTab(url: URL(string: "https://first.example"))
        let second = manager.createTab(url: URL(string: "https://second.example"))

        #expect(manager.activeTabID == second.id)
        #expect(manager.activeTab?.id == second.id)
        #expect(first.id != second.id)
    }
}
