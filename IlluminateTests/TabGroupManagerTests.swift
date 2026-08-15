//
//  TabGroupManagerTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/8/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct TabGroupManagerTests {
    private func makeManager() -> TabGroupManager {
        TabGroupManager(profileID: UUID(), isPersistenceEnabled: false)
    }

    @Test func movingTabToAnotherGroupPreservesExclusiveMembershipAndInsertionOrder() {
        let manager = makeManager()
        let firstTabID = UUID()
        let movedTabID = UUID()
        let destinationTabID = UUID()
        let sourceGroup = manager.createGroup(
            name: "Research",
            color: .blue,
            tabIDs: [firstTabID, movedTabID]
        )
        let destinationGroup = manager.createGroup(
            name: "Travel",
            color: .green,
            tabIDs: [destinationTabID]
        )

        manager.moveTabToGroup(movedTabID, targetGroupID: destinationGroup.id, at: 0)

        #expect(sourceGroup.tabIDs == [firstTabID])
        #expect(destinationGroup.tabIDs == [movedTabID, destinationTabID])
        #expect(manager.group(for: movedTabID)?.id == destinationGroup.id)
        #expect(manager.group(for: movedTabID)?.id != sourceGroup.id)
    }

    @Test func closingAndRestoringGroupPreservesMetadataAndTabRecoveryPayloads() {
        let manager = makeManager()
        let firstTab = Tab(
            id: UUID(),
            url: URL(string: "https://one.example/path"),
            title: "One"
        )
        let secondTab = Tab(
            id: UUID(),
            url: URL(string: "https://two.example/path"),
            title: "Two"
        )
        let group = manager.createGroup(
            name: "Trip planning",
            color: .purple,
            tabIDs: [firstTab.id, secondTab.id]
        )
        group.isCollapsed = true

        manager.closeGroup(group.id, tabs: [firstTab, secondTab])

        #expect(manager.group(byID: group.id) == nil)
        #expect(manager.group(for: firstTab.id) == nil)
        #expect(manager.closedGroups.count == 1)

        let restoredSnapshot = manager.restoreLatestGroup()
        let restoredGroup = manager.group(byID: group.id)

        #expect(restoredSnapshot?.groupPayload.name == "Trip planning")
        #expect(restoredSnapshot?.groupPayload.color == TabGroupColor.purple.rawValue)
        #expect(restoredSnapshot?.groupPayload.tabIDs == [firstTab.id, secondTab.id])
        #expect(restoredSnapshot?.tabPayloads.map(\.id) == [firstTab.id, secondTab.id])
        #expect(restoredGroup?.name == "Trip planning")
        #expect(restoredGroup?.groupColor == .purple)
        #expect(restoredGroup?.isCollapsed == true)
        #expect(restoredGroup?.tabIDs.isEmpty == true)
        #expect(manager.closedGroups.isEmpty)
    }

    @Test func reorderingUngroupedTabBetweenGroupedTabsJoinsItAndSynchronizesGroupOrder() {
        let manager = makeManager()
        let firstTabID = UUID()
        let insertedTabID = UUID()
        let thirdTabID = UUID()
        let group = manager.createGroup(
            name: "Work",
            color: .orange,
            tabIDs: [firstTabID, thirdTabID]
        )

        manager.handleTabsReordered([firstTabID, insertedTabID, thirdTabID])

        #expect(group.tabIDs == [firstTabID, insertedTabID, thirdTabID])
        #expect(manager.group(for: insertedTabID)?.id == group.id)
    }
}
