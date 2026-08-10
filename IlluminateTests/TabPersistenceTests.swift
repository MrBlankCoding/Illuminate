//
//  TabPersistenceTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/9/26.
//

import Testing
import Foundation
import AppKit
@testable import Illuminate

@MainActor
struct TabPersistenceTests {

    @Test func testSessionSerialization() throws {
        let firstID = UUID()
        let secondID = UUID()
        let state = SessionState(
            tabs: [
                TabTransferPayload(
                    id: firstID,
                    url: URL(string: "https://apple.com"),
                    title: "Apple"
                ),
                TabTransferPayload(
                    id: secondID,
                    url: URL(string: "https://google.com"),
                    title: "Google"
                )
            ],
            activeTabID: secondID
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SessionState.self, from: data)
        let decodedTabs = decoded.tabs
        let decodedActiveTabID = decoded.activeTabID

        #expect(decodedTabs?.count == 2)
        #expect(decodedTabs?[0].title == "Apple")
        #expect(decodedTabs?[1].title == "Google")
        #expect(decodedActiveTabID == secondID)
    }

    @Test func testCrashRecovery() {
        let tabId1 = UUID()
        let tabId2 = UUID()
        let payload1 = TabTransferPayload(
            id: tabId1,
            url: URL(string: "https://github.com"),
            title: "GitHub"
        )
        let payload2 = TabTransferPayload(
            id: tabId2,
            url: URL(string: "https://swift.org"),
            title: "Swift"
        )

        let restoredTabs = [Tab(payload: payload1), Tab(payload: payload2)]

        #expect(restoredTabs.count == 2)
        #expect(restoredTabs.contains { $0.id == tabId1 && $0.title == "GitHub" })
        #expect(restoredTabs.contains { $0.id == tabId2 && $0.title == "Swift" })
    }

    @Test func testTabClosingCleanup() throws {
        let tabManager = TabManager(isPersistenceEnabled: false)

        let tab = tabManager.createTab(url: URL(string: "https://apple.com"))
        let tabID = tab.id

        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let base = paths[0].appendingPathComponent("Illuminate/TabAssets", isDirectory: true)
        let tabFolder = base.appendingPathComponent(tabID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tabFolder, withIntermediateDirectories: true)
        let dummyAsset = tabFolder.appendingPathComponent("snapshot.png")
        try "dummy".data(using: .utf8)?.write(to: dummyAsset)

        #expect(FileManager.default.fileExists(atPath: tabFolder.path))

        tabManager.closeTab(id: tabID)
        let remainingTabIDs = tabManager.tabs.map(\.id)

        #expect(!remainingTabIDs.contains(tabID))
        #expect(!FileManager.default.fileExists(atPath: tabFolder.path), "Tab folder should be deleted from disk")
    }
}
