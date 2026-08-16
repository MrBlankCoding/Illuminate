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

    @Test func createsEmptyGroupWithRequestedMetadata() {
        let manager = makeManager()

        let group = manager.createGroup(name: "Reading", color: .green)

        #expect(manager.groups.count == 1)
        #expect(group.name == "Reading")
        #expect(group.groupColor == .green)
        #expect(group.isNew)
        #expect(group.isEmpty)
    }

    @Test func creatingGroupMovesTabsOutOfExistingGroup() {
        let manager = makeManager()
        let tabID = UUID()
        let original = manager.createGroup(name: "Original", tabIDs: [tabID])

        let replacement = manager.createGroup(name: "Replacement", tabIDs: [tabID])

        #expect(original.tabIDs.isEmpty)
        #expect(manager.group(for: tabID)?.id == replacement.id)
        #expect(manager.group(byID: original.id) == nil)
    }

    @Test func groupLookupsAndPositionReflectStoredGroups() {
        let manager = makeManager()
        let tabID = UUID()
        let first = manager.createGroup(name: "First", tabIDs: [tabID])
        let second = manager.createGroup(name: "Second")

        #expect(manager.group(for: tabID)?.id == first.id)
        #expect(manager.group(byID: second.id)?.name == "Second")
        #expect(manager.position(ofGroup: first.id) == 0)
        #expect(manager.position(ofGroup: second.id) == 1)
        #expect(manager.position(ofGroup: UUID()) == nil)
    }

    @Test func deletingGroupRemovesItsTabMembership() {
        let manager = makeManager()
        let tabID = UUID()
        let group = manager.createGroup(tabIDs: [tabID])

        manager.deleteGroup(group.id)

        #expect(manager.groups.isEmpty)
        #expect(manager.group(for: tabID) == nil)
    }

    @Test func deletingUnknownGroupDoesNotChangeStoredGroups() {
        let manager = makeManager()
        let group = manager.createGroup(name: "Kept")

        manager.deleteGroup(UUID())

        #expect(manager.groups.map(\.id) == [group.id])
    }

    @Test func renameAndColorChangeUpdateExistingGroup() {
        let manager = makeManager()
        let group = manager.createGroup(name: "Old", color: .blue)

        manager.renameGroup(group.id, to: "New")
        manager.changeGroupColor(group.id, to: .pink)

        #expect(group.name == "New")
        #expect(group.groupColor == .pink)
    }

    @Test func changesToUnknownGroupAreNoOps() {
        let manager = makeManager()

        manager.renameGroup(UUID(), to: "Missing")
        manager.changeGroupColor(UUID(), to: .red)
        manager.toggleCollapse(UUID())

        #expect(manager.groups.isEmpty)
    }

    @Test func addingTabToGroupMovesItFromPriorGroup() {
        let manager = makeManager()
        let tabID = UUID()
        let first = manager.createGroup(tabIDs: [tabID])
        let second = manager.createGroup()

        manager.addTabToGroup(tabID, groupID: second.id)

        #expect(manager.group(byID: first.id) == nil)
        #expect(second.tabIDs == [tabID])
        #expect(manager.group(for: tabID)?.id == second.id)
    }

    @Test func removingLastTabDeletesEmptyGroup() {
        let manager = makeManager()
        let tabID = UUID()
        let group = manager.createGroup(tabIDs: [tabID])

        manager.removeTabFromGroup(tabID)

        #expect(manager.group(byID: group.id) == nil)
        #expect(manager.group(for: tabID) == nil)
    }

    @Test func moveTabWithoutIndexAppendsToDestination() {
        let manager = makeManager()
        let existing = UUID()
        let moved = UUID()
        let group = manager.createGroup(tabIDs: [existing])

        manager.moveTabToGroup(moved, targetGroupID: group.id)

        #expect(group.tabIDs == [existing, moved])
        #expect(manager.group(for: moved)?.id == group.id)
    }

    @Test func moveTabClampsRequestedInsertionIndex() {
        let manager = makeManager()
        let existing = UUID()
        let moved = UUID()
        let group = manager.createGroup(tabIDs: [existing])

        manager.moveTabToGroup(moved, targetGroupID: group.id, at: -1)

        #expect(group.tabIDs == [moved, existing])
    }

    @Test func collapseOperationsAreIdempotentAndToggleState() {
        let manager = makeManager()
        let group = manager.createGroup()

        manager.collapseGroup(group.id)
        manager.collapseGroup(group.id)
        #expect(group.isCollapsed)

        manager.toggleCollapse(group.id)
        #expect(!group.isCollapsed)

        manager.expandGroup(group.id)
        manager.expandGroup(group.id)
        #expect(!group.isCollapsed)
    }

    @Test func restoringWithoutClosedGroupsReturnsNil() {
        let manager = makeManager()

        #expect(manager.restoreLatestGroup() == nil)
        #expect(manager.restoreGroup(at: 0) == nil)
    }
}
