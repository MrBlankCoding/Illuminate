//
//  TabManagerSelectionTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//


import Foundation
import Testing
@testable import Illuminate

@MainActor
struct TabManagerSelectionTests {
    private func makeTabManager() -> TabManager {
        TabManager(
            profile: BrowserProfile(name: "Selection Test"),
            urlSynchronizer: URLSynchronizer(),
            isPersistenceEnabled: false
        )
    }

    @Test func switchingToUnknownTabDoesNotInvalidateSelection() {
        let manager = makeTabManager()
        let first = manager.createTab(url: URL(string: "https://one.example"))
        let second = manager.createTab(url: URL(string: "https://two.example"))

        manager.switchTo(second.id)
        #expect(manager.activeTabID == second.id)

        let staleID = UUID()
        manager.switchTo(staleID)

        #expect(manager.activeTabID == second.id)
        #expect(manager.activeTab?.id == second.id)
        #expect(manager.activeTab?.url == URL(string: "https://two.example"))
    }
}
