//
//  TabGroupManagerEdgeCaseTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct TabGroupManagerEdgeCaseTests {
    private func makeManager() -> TabGroupManager {
        TabGroupManager(profileID: UUID(), isPersistenceEnabled: false)
    }

    @Test func orderedTabIDsKeepsGroupedTabsTogetherAndPreservesStandaloneTabs() {
        let manager = makeManager()
        let tabA = UUID()
        let tabB = UUID()
        let tabC = UUID()
        let tabD = UUID()

        _ = manager.createGroup(name: "Work", tabIDs: [tabB, tabC])

        let ordered = manager.orderedTabIDs(allTabs: [
            Tab(id: tabA, url: URL(string: "https://a.example"), title: "A"),
            Tab(id: tabB, url: URL(string: "https://b.example"), title: "B"),
            Tab(id: tabC, url: URL(string: "https://c.example"), title: "C"),
            Tab(id: tabD, url: URL(string: "https://d.example"), title: "D")
        ])

        #expect(ordered == [tabB, tabC, tabA, tabD])
    }

    @Test func restoreLatestGroupReturnsNilWhenNoClosedGroupsExist() {
        let manager = makeManager()

        #expect(manager.restoreLatestGroup() == nil)
        #expect(manager.closedGroups.isEmpty)
    }

    @Test func handleTabClosedRemovesMembershipWithoutDestroyingUnrelatedGroups() {
        let manager = makeManager()
        let keepTab = UUID()
        let movingTab = UUID()
        let groupA = manager.createGroup(name: "A", tabIDs: [keepTab, movingTab])
        let groupB = manager.createGroup(name: "B", tabIDs: [UUID()])

        manager.handleTabClosed(movingTab)

        #expect(groupA.tabIDs == [keepTab])
        #expect(manager.group(for: keepTab)?.id == groupA.id)
        #expect(manager.group(byID: groupB.id)?.name == "B")
    }
}
