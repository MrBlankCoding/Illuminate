//
//  TabGroupTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import Testing
@testable import Illuminate

@MainActor
struct TabGroupTests {
    @Test func emptyGroupReportsNoTabs() {
        let group = TabGroup()

        #expect(group.tabCount == 0)
        #expect(group.isEmpty)
    }

    @Test func populatedGroupReportsMembership() {
        let tabID = UUID()
        let group = TabGroup(tabIDs: [tabID])

        #expect(group.tabCount == 1)
        #expect(!group.isEmpty)
        #expect(group.contains(tabID))
        #expect(!group.contains(UUID()))
    }

    @Test func addTabAppendsNewTab() {
        let tabID = UUID()
        let group = TabGroup()

        group.addTab(tabID)

        #expect(group.tabIDs == [tabID])
    }

    @Test func addTabDoesNotDuplicateExistingTab() {
        let tabID = UUID()
        let group = TabGroup(tabIDs: [tabID])

        group.addTab(tabID)

        #expect(group.tabIDs == [tabID])
    }

    @Test func addTabsPreservesNewIDsInInputOrder() {
        let ids = [UUID(), UUID(), UUID()]
        let group = TabGroup()

        group.addTabs(ids)

        #expect(group.tabIDs == ids)
    }

    @Test func addTabsIgnoresExistingAndRepeatedIDs() {
        let first = UUID()
        let second = UUID()
        let group = TabGroup(tabIDs: [first])

        group.addTabs([first, second, second])

        #expect(group.tabIDs == [first, second])
    }

    @Test func removeTabRemovesOnlyRequestedTab() {
        let first = UUID()
        let second = UUID()
        let group = TabGroup(tabIDs: [first, second])

        group.removeTab(first)

        #expect(group.tabIDs == [second])
    }

    @Test func removingUnknownTabIsNoOp() {
        let tabID = UUID()
        let group = TabGroup(tabIDs: [tabID])

        group.removeTab(UUID())

        #expect(group.tabIDs == [tabID])
    }

    @Test func insertTabClampsNegativeIndexToStart() {
        let existing = UUID()
        let inserted = UUID()
        let group = TabGroup(tabIDs: [existing])

        group.insertTab(inserted, at: -10)

        #expect(group.tabIDs == [inserted, existing])
    }

    @Test func insertTabClampsLargeIndexToEnd() {
        let existing = UUID()
        let inserted = UUID()
        let group = TabGroup(tabIDs: [existing])

        group.insertTab(inserted, at: 99)

        #expect(group.tabIDs == [existing, inserted])
    }

    @Test func insertTabDoesNotMoveExistingTab() {
        let first = UUID()
        let second = UUID()
        let group = TabGroup(tabIDs: [first, second])

        group.insertTab(first, at: 1)

        #expect(group.tabIDs == [first, second])
    }

    @Test func moveTabClampsDestinationAndRetainsMembership() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        let group = TabGroup(tabIDs: [first, second, third])

        group.moveTab(fromIndex: 0, toIndex: 99)

        #expect(group.tabIDs == [second, third, first])
        #expect(group.index(of: first) == 2)
    }

    @Test func movingFromInvalidIndexIsNoOp() {
        let tabID = UUID()
        let group = TabGroup(tabIDs: [tabID])

        group.moveTab(fromIndex: -1, toIndex: 0)

        #expect(group.tabIDs == [tabID])
    }
}
