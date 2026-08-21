//
//  IlluminateTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 3/8/26.
//

import Testing
import AppKit
import Foundation
import SwiftUI
@testable import Illuminate

// test for cacheing images or something.

struct IlluminateTests {

    @Test func testTabAssetPersistence() async throws {
        let tabID = UUID()
        let image = await MainActor.run {
            let size = NSSize(width: 10, height: 10)
            let img = NSImage(size: size)
            img.lockFocus()
            NSColor.red.set()
            NSRect(origin: .zero, size: size).fill()
            img.unlockFocus()
            return img
        }

        let base = FileManager.default
            .illuminateAppSupportDirectory()
            .appendingPathComponent("TabAssets", isDirectory: true)
        let tabFolder = base.appendingPathComponent(tabID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tabFolder, withIntermediateDirectories: true)

        let faviconURL = tabFolder.appendingPathComponent("favicon.png")
        try image.pngData()?.write(to: faviconURL)

        #expect(FileManager.default.fileExists(atPath: tabFolder.appendingPathComponent("favicon.png").path))
        
        let restoredTab = await MainActor.run {
            Tab(id: tabID, url: URL(string: "https://google.com"), title: "Google")
        }
        
        await MainActor.run {
            restoredTab.loadAssets()
        }

        let didLoadAssets = try await waitForAssets(on: restoredTab)

        await MainActor.run {
            #expect(didLoadAssets)
            #expect(restoredTab.favicon != nil)
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: tabFolder)
    }

    private func waitForAssets(on tab: Illuminate.Tab, timeout: Duration = .seconds(2)) async throws -> Bool {
        let deadline = ContinuousClock.now + timeout

        while ContinuousClock.now < deadline {
            let hasAssets = await MainActor.run {
                tab.favicon != nil
            }

            if hasAssets {
                return true
            }

            try await Task.sleep(for: .milliseconds(50))
        }

        return await MainActor.run {
            tab.favicon != nil
        }
    }
}
